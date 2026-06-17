import 'dart:async';
import 'dart:io' show Platform, Process, ProcessStartMode;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart';

/// Workspace/file actions, service-driven so both the application menu (T-48)
/// and the project-switcher dropdown drive the same logic through registered
/// commands rather than duplicating it. Lifted out of `app.dart` so the menu
/// extension can reach it without depending on private widget state.
class FileActions {
  const FileActions(this.services);

  final KernelServices services;

  /// The workspace tab activated after a project opens, so a freshly-opened
  /// repo lands on the Claude pane (matches the historical switcher behavior).
  static const _landingTab = 'claude.primary';

  /// Open the git repo at [path]; on success activate the landing tab.
  Future<bool> openPath(String path) async {
    final ok = await services.project.open(path);
    if (ok) services.panels.activateTab(Slots.workspace, _landingTab);
    return ok;
  }

  /// Launch a second clide window as a detached process.
  void newWindow() {
    Process.start(Platform.resolvedExecutable, const [], mode: ProcessStartMode.detached);
  }

  /// Close the current workspace (back to the welcome screen).
  void closeWorkspace() => services.project.close();

  /// Pick a folder via the native directory picker and open it. Falls back to
  /// a typed-path dialog when no native picker is available
  /// ([MissingPluginException]); surfaces a "not a repo" dialog when the chosen
  /// directory isn't a git repository.
  Future<void> openFolder() async {
    try {
      final picked = await services.window.pickDirectory();
      if (picked != null) {
        final ok = await openPath(picked);
        if (!ok) {
          services.dialog.show((ctx, dismiss) => NotARepoDialog(path: picked, onDismiss: () => dismiss()));
        }
      }
      return;
    } on MissingPluginException {
      // No native picker — fall through to the typed-path dialog.
    }

    services.dialog.show<String>((ctx, dismiss) {
      return OpenFolderDialog(
        onOpen: (path) async {
          if (await openPath(path)) dismiss(path);
        },
        onCancel: () => dismiss(),
      );
    });
  }
}

/// Typed-path fallback for opening a project when no native directory picker is
/// available. (Moved verbatim from `app.dart` so [FileActions] owns it.)
class OpenFolderDialog extends StatefulWidget {
  const OpenFolderDialog({super.key, required this.onOpen, required this.onCancel});
  final Future<void> Function(String path) onOpen;
  final VoidCallback onCancel;

  @override
  State<OpenFolderDialog> createState() => _OpenFolderDialogState();
}

class _OpenFolderDialogState extends State<OpenFolderDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onOpen(path);
    } catch (_) {
      if (mounted) setState(() => _error = 'Not a git repository');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClideText('Open project', fontSize: 16, fontWeight: FontWeight.w600),
          const SizedBox(height: 4),
          const ClideText('Enter the path to a git repository.', muted: true, fontSize: 13),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              border: Border.all(color: tokens.globalBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: EditableText(
              controller: _controller,
              focusNode: _focus,
              style: TextStyle(
                color: tokens.globalForeground,
                fontSize: 14,
                fontFamily: ClideSettings.fonts.monoOf(context),
                fontFamilyFallback: clideMonoFamilyFallback,
              ),
              cursorColor: tokens.globalForeground,
              backgroundCursorColor: tokens.globalTextMuted,
              onSubmitted: (_) => unawaited(_submit()),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 8), ClideText(_error!, color: tokens.statusError, fontSize: 12)],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClideButton(label: 'Cancel', onPressed: widget.onCancel),
              const SizedBox(width: 8),
              ClideButton(label: _loading ? 'Opening…' : 'Open', onPressed: _loading ? null : _submit),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown when a chosen directory isn't a git repository. (Moved verbatim from
/// `app.dart`.)
class NotARepoDialog extends StatelessWidget {
  const NotARepoDialog({super.key, required this.path, required this.onDismiss});
  final String path;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideSettings.theme.of(context).surface;
    return Container(
      width: 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.modalSurfaceBackground,
        border: Border.all(color: tokens.modalSurfaceBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ClideText('No git repo found', fontSize: 16, fontWeight: FontWeight.w600),
          const SizedBox(height: 8),
          ClideText(path, muted: true, fontSize: 13),
          const SizedBox(height: 8),
          const ClideText('A clide project root requires a git repository.', muted: true, fontSize: 13),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [ClideButton(label: 'OK', onPressed: () => onDismiss())],
          ),
        ],
      ),
    );
  }
}
