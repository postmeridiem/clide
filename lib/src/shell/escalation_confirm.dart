/// The in-app confirm for an agent's escalating command (D-115).
///
/// The dispatcher's [EscalationGate] in the app: it shows which agent wants
/// to run which exact command, with every argument it would run with, and
/// returns the user's [EscalationVerdict]. Deny is the default — dismissing
/// the modal (backdrop tap) denies too.
library;

import 'dart:convert';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/daemon/escalation.dart';
import 'package:clide/src/daemon/risk_tiers.dart' show cliSpelling;
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// Show the confirm for [request] on [dialog]; anything but an explicit
/// allow is a deny.
Future<EscalationVerdict> confirmEscalation(DialogRouter dialog, EscalationRequest request) async {
  final verdict = await dialog.show<EscalationVerdict>((c, dismiss) => EscalationConfirmDialog(request: request, onResolve: dismiss));
  return verdict ?? EscalationVerdict.deny;
}

/// The command as the user would type it, then one line per argument.
/// Values are shown exactly (JSON for anything that isn't a string) so what
/// the user approves is what runs.
String describeEscalation(EscalationRequest r) {
  final lines = <String>[cliSpelling(r.command)];
  final keys = r.args.keys.toList()..sort();
  for (final k in keys) {
    final v = r.args[k];
    if (v == null) continue;
    lines.add('  $k: ${v is String ? v : jsonEncode(v)}');
  }
  if (r.reason != null) lines.add('  (${r.reason})');
  return lines.join('\n');
}

class EscalationConfirmDialog extends StatelessWidget {
  const EscalationConfirmDialog({super.key, required this.request, required this.onResolve});

  final EscalationRequest request;
  final void Function([EscalationVerdict? verdict]) onResolve;

  @override
  Widget build(BuildContext context) {
    final t = ClideSettings.theme.of(context).surface;
    String s(String key, String placeholder) => ClideSettings.i18n.string(context, key, namespace: 'core', placeholder: placeholder);
    final body =
        ClideKernel.maybeOf(context)?.i18n.interpolated(
          'escalation.body',
          namespace: 'core',
          placeholder: '{agent} wants to run:',
          replacers: [I18nReplacer(from: '{agent}', replace: request.agent.label)],
        ) ??
        '${request.agent.label} wants to run:';
    return ClideSurface(
      width: 520,
      color: t.modalSurfaceBackground,
      border: t.modalSurfaceBorder,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClideText(s('escalation.title', 'Allow an agent to run this?'), fontSize: clideFontBody, color: t.globalForeground),
          const SizedBox(height: 6),
          ClideText(body, muted: true, fontSize: clideFontSmall),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: ClideText(
                describeEscalation(request),
                fontFamily: ClideSettings.fonts.monoOf(context),
                fontSize: clideFontSmall,
                color: t.globalForeground,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClideText(
            s('escalation.warning', 'This can run code or change what clide trusts. Allow it only if you expected it.'),
            fontSize: clideFontMeta,
            color: t.statusWarning,
          ),
          const SizedBox(height: 14),
          // A Wrap, not a Row: three labels (longer still in Dutch) outgrow
          // the dialog's width, and must flow rather than overflow.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              ClideButton(label: s('escalation.deny', 'Deny'), onPressed: () => onResolve(EscalationVerdict.deny)),
              ClideButton(label: s('escalation.session', 'Allow for this session'), onPressed: () => onResolve(EscalationVerdict.session)),
              // The narrowest allow is the highlighted one.
              ClideButton(label: s('escalation.once', 'Allow once'), variant: ClideButtonVariant.primary, onPressed: () => onResolve(EscalationVerdict.once)),
            ],
          ),
        ],
      ),
    );
  }
}
