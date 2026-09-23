import 'package:clide/clide.dart';
import 'package:clide/extension/src/contribution.dart';
import 'package:flutter/foundation.dart';

class CommandRegistry extends ChangeNotifier {
  final Map<String, CommandContribution> _byCommand = {};

  /// Throws [StateError] when [CommandContribution.command] is already
  /// registered — a silent overwrite let two owners fight over one id.
  void register(CommandContribution cmd) {
    if (_byCommand.containsKey(cmd.command)) {
      throw StateError('duplicate command id: ${cmd.command}');
    }
    _byCommand[cmd.command] = cmd;
    notifyListeners();
  }

  /// Remove [command]. With [owner], only when that exact contribution is
  /// the one registered, so a stale owner can't remove its successor.
  void unregister(String command, {CommandContribution? owner}) {
    final current = _byCommand[command];
    if (current == null || (owner != null && !identical(current, owner))) return;
    _byCommand.remove(command);
    notifyListeners();
  }

  Iterable<CommandContribution> get all => _byCommand.values;
  CommandContribution? get(String command) => _byCommand[command];

  Future<IpcResponse> execute(String command, {List<String> args = const []}) async {
    final c = _byCommand[command];
    if (c == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: 'no such command: $command'),
      );
    }
    return c.run(args);
  }
}
