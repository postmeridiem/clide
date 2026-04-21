import 'package:clide/clide.dart';
import 'package:clide_app/extension/src/contribution.dart';
import 'package:flutter/foundation.dart';

class CommandRegistry extends ChangeNotifier {
  final Map<String, CommandContribution> _byCommand = {};

  void register(CommandContribution cmd) {
    _byCommand[cmd.command] = cmd;
    notifyListeners();
  }

  void unregister(String command) {
    if (_byCommand.remove(command) != null) notifyListeners();
  }

  Iterable<CommandContribution> get all => _byCommand.values;
  CommandContribution? get(String command) => _byCommand[command];

  Future<IpcResponse> execute(
    String command, {
    List<String> args = const [],
  }) async {
    final c = _byCommand[command];
    if (c == null) {
      return IpcResponse.err(
        id: '',
        error: IpcError(
          code: IpcExitCode.notFound,
          kind: IpcErrorKind.notFound,
          message: 'no such command: $command',
        ),
      );
    }
    return c.run(args);
  }
}
