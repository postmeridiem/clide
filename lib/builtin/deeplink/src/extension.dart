/// `clide://` deep-link handler (T-56, D-90).
///
/// Registers the `deeplink.invoke` command that the CLI routes a clide:// URL to
/// (via parseArgv). Because a clide:// link is an UNTRUSTED external vector, the
/// handler is doubly defensive: it only honours [kDeepLinkSafeActions]
/// (default-deny) AND it prompts the user before doing anything.
library;

import 'package:clide/builtin/deeplink/src/deep_link.dart';
import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class DeepLinkExtension extends ClideExtension {
  @override
  String get id => 'builtin.deeplink';
  @override
  String get title => 'Deep links';
  @override
  String get version => '0.1.0';

  ClideExtensionContext? _ctx;

  @override
  List<ContributionPoint> get contributions => [
    CommandContribution(id: 'deeplink.invoke', command: 'deeplink.invoke', title: 'Open a clide:// deep link', run: _invoke),
  ];

  @override
  Future<void> activate(ClideExtensionContext ctx) async => _ctx = ctx;

  @override
  Future<void> deactivate() async => _ctx = null;

  Future<IpcResponse> _invoke(List<String> args) async {
    final ctx = _ctx;
    if (ctx == null) return IpcResponse.ok(id: '', data: const {'status': 'not-activated'});

    final url = args.isEmpty ? null : args.first;
    final action = url == null ? null : parseDeepLink(url);
    // Default-deny: a malformed or non-allowlisted link never acts.
    if (action == null) {
      return IpcResponse.ok(id: '', data: {'status': 'rejected', 'url': url});
    }

    // Always confirm — an external page must not silently drive the IDE (D-90).
    final ok = await ctx.dialog.show<bool>((c, dismiss) => _DeepLinkConfirmDialog(action: action, onResolve: dismiss));
    if (ok != true) return IpcResponse.ok(id: '', data: const {'status': 'declined'});

    switch (action.name) {
      case 'open':
        await ctx.ipc.request('editor.open', args: {'path': action.path, if (action.line != null) 'line': action.line});
        return IpcResponse.ok(id: '', data: {'status': 'opened', 'path': action.path});
    }
    return IpcResponse.ok(id: '', data: const {'status': 'rejected'});
  }
}

/// Confirmation modal for an incoming deep link — frames it as untrusted and
/// requires an explicit Open. Cancel (the default) declines.
class _DeepLinkConfirmDialog extends StatelessWidget {
  const _DeepLinkConfirmDialog({required this.action, required this.onResolve});

  final DeepLinkAction action;
  final void Function([bool? result]) onResolve;

  @override
  Widget build(BuildContext context) {
    final t = ClideSettings.theme.of(context).surface;
    return ClideSurface(
      width: 440,
      color: t.modalSurfaceBackground,
      border: t.modalSurfaceBorder,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText('Open an external link?', fontSize: clideFontBody, color: t.globalForeground),
          const SizedBox(height: 6),
          ClideText('A clide:// link from outside the app is asking to:', muted: true, fontSize: clideFontSmall),
          const SizedBox(height: 8),
          ClideText(action.describe, fontFamily: ClideSettings.fonts.monoOf(context), fontSize: clideFontSmall, color: t.globalForeground),
          const SizedBox(height: 8),
          ClideText('Only allow this if you trust where the link came from.', fontSize: clideFontMeta, color: t.statusWarning),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(label: 'Cancel', onPressed: () => onResolve(false)),
              const SizedBox(width: 8),
              ClideButton(label: 'Open', variant: ClideButtonVariant.primary, onPressed: () => onResolve(true)),
            ],
          ),
        ],
      ),
    );
  }
}
