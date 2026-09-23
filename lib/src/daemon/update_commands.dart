/// `clide app update [--install]` — check for a newer release, and install it
/// (T-621, T-47 P2/P3; D-113). The About box's Check / Install buttons drive
/// the same verb, so the CLI and the UI stay one surface (D-6).
///
/// Progress goes out as `app.update` events — `{phase, fraction?, latest}`,
/// then `{phase: failed, error}` or `{phase: restarting}` — which the About box
/// renders and `clide tail --events` shows.
///
/// Every call is an explicit user action: nothing here runs on launch or on a
/// timer (D-64, POLICY.md).
library;

import 'dart:async';

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/event_sink.dart';
import '../update/self_update.dart';
import '../update/update_check.dart';
import 'dispatcher.dart';

/// How long after answering an install the windows restart, so the reply
/// reaches the caller first.
const Duration kRestartGrace = Duration(milliseconds: 300);

/// Register `app.update`. [updater] is null when this run can't update itself
/// (a development build); [restartWindows] moves every window onto the new
/// install once it is in place.
void registerUpdateCommands(
  DaemonDispatcher d,
  DaemonEventSink events, {
  required String repositoryUrl,
  required String currentVersion,
  required SelfUpdater? updater,
  required Future<void> Function() restartWindows,
  GithubFetch fetch = githubGet,
  Duration restartGrace = kRestartGrace,
}) {
  var installing = false;

  void emit(Map<String, Object?> data) => events.emit(IpcEvent(subsystem: 'app', kind: 'app.update', timestamp: DateTime.now(), data: data));

  d.register('app.update', (req) async {
    final install = req.args['install'] == true;
    final r = await checkForUpdate(repositoryUrl: repositoryUrl, currentVersion: currentVersion, fetch: fetch);
    switch (r) {
      case UpdateCheckFailed(:final message):
        return _err(req.id, "couldn't check for updates: $message");
      case UpdateUpToDate():
        return IpcResponse.ok(id: req.id, data: {'current': currentVersion, 'available': false});
      case UpdateAvailable(:final latest, :final url, :final bundle):
        final info = <String, Object?>{
          'current': currentVersion,
          'latest': latest,
          'url': url,
          'available': true,
          'installable': updater != null && bundle != null,
        };
        if (!install) return IpcResponse.ok(id: req.id, data: info);
        if (updater == null) return _err(req.id, 'this clide runs from a development build — update it with `make install`');
        if (bundle == null) return _err(req.id, 'the v$latest release has no bundle for this platform');
        if (installing) return _err(req.id, 'an update is already being installed');
        installing = true;
        try {
          await updater.install(bundle, onProgress: (phase, {fraction}) => emit({'phase': phase.name, 'fraction': ?fraction, 'latest': latest}));
        } on SelfUpdateException catch (e) {
          emit({'phase': 'failed', 'error': e.message, 'latest': latest});
          return _err(req.id, 'update failed: ${e.message}');
        } catch (e) {
          emit({'phase': 'failed', 'error': '$e', 'latest': latest});
          return _err(req.id, 'update failed: $e');
        } finally {
          installing = false;
        }
        emit({'phase': UpdatePhase.restarting.name, 'latest': latest});
        unawaited(Future<void>.delayed(restartGrace, restartWindows));
        return IpcResponse.ok(id: req.id, data: {...info, 'installed': latest, 'restarting': true});
    }
  }, schema: const CommandSchema(args: {'install': ArgSpec(type: ArgType.boolean)}));
}

IpcResponse _err(String id, String message) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: message),
);
