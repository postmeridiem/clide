import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/src/cli_install.dart';

/// VS Code-style "Install 'clide' command in PATH" affordance (T-212).
///
/// Registers a palette/CLI command that copies the bundled C client into a
/// PATH dir, and on activation proactively warns when `clide` is missing from
/// PATH or — the dogfood footgun — resolves to a stale symlink into the
/// Flutter GUI bundle instead of the C client. Detection and the copy live in
/// the Flutter-free [CliInstaller]; this extension only wires it to the
/// command and notification surfaces.
class CliInstallExtension extends ClideExtension {
  CliInstallExtension({CliInstaller? installer}) : _installer = installer;

  CliInstaller? _installer;
  ClideExtensionContext? _ctx;

  CliInstaller get _resolved => _installer ??= CliInstaller(resolvedExecutable: Platform.resolvedExecutable);

  @override
  String get id => 'builtin.cli-install';
  @override
  String get title => 'CLI Install';
  @override
  String get version => '0.1.0';

  @override
  Future<void> activate(ClideExtensionContext ctx) async {
    _ctx = ctx;
    // Proactive launch-time detection (desktop only). Non-modal: we notify
    // and point at the command rather than auto-installing — no surprise
    // filesystem writes (interaction-zone discipline, D-78).
    if (!(Platform.isLinux || Platform.isMacOS)) return;
    switch (_resolved.inspect().state) {
      case CliInstallState.missing:
        ctx.notify.warn(
          'The `clide` command is not on your PATH. Run "clide: Install '
          'command in PATH" from the command palette to reach it from a shell.',
          title: 'clide CLI not installed',
        );
      case CliInstallState.staleGui:
        ctx.notify.warn(
          '`clide` on your PATH points at the GUI app, not the CLI client — '
          'a bare `clide` launches a second app. Run "clide: Install command '
          'in PATH" to replace it.',
          title: 'clide CLI is stale',
        );
      case CliInstallState.devTree:
        ctx.notify.info(
          '`clide` on your PATH is the dev-tree build, not a packaged install '
          '— fine for development; rebuild it with `make clide-cli`.',
          title: 'clide CLI: dev build',
        );
      case CliInstallState.installed:
        break;
    }
  }

  @override
  List<ContributionPoint> get contributions => [
        CommandContribution(
          id: 'clide.installCli',
          command: 'clide.installCli',
          title: "clide: Install 'clide' command in PATH",
          run: (_) async {
            final r = _resolved.install();
            final ctx = _ctx;
            if (r.ok) {
              ctx?.notify.success(r.message, title: 'clide CLI installed');
              return IpcResponse.ok(id: '', data: {
                'installed': r.installedPath,
                'onPath': r.onPath,
              });
            }
            ctx?.notify.error(r.message, title: 'clide CLI install failed');
            return IpcResponse.err(
              id: '',
              error: IpcError(
                code: IpcExitCode.toolError,
                kind: IpcErrorKind.toolError,
                message: r.message,
              ),
            );
          },
        ),
      ];
}
