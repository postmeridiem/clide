import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class IpcStatusItem extends StatelessWidget {
  const IpcStatusItem({super.key, required this.ipc});

  final DaemonClient ipc;

  static const _ns = 'builtin.ipc-status';

  @override
  Widget build(BuildContext context) {
    final kernel = ClideKernel.of(context);
    final tokens = ClideTheme.of(context).surface;
    return ListenableBuilder(
      listenable: Listenable.merge([ipc, kernel.i18n]),
      builder: (ctx, _) {
        final connected = ipc.isConnected;
        final color = connected ? tokens.statusSuccess : tokens.statusError;
        final i = kernel.i18n;
        final label = connected
            ? i.string('connected', namespace: _ns, placeholder: 'connected')
            : i.string('disconnected',
                namespace: _ns, placeholder: 'disconnected');
        final hint = connected
            ? i.string('connected.hint',
                namespace: _ns,
                placeholder: 'clide daemon is reachable over the local socket')
            : i.string('disconnected.hint',
                namespace: _ns,
                placeholder:
                    'clide daemon is not running — start it with `clide --daemon`');
        return Semantics(
          label: label,
          hint: hint,
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClideIcon(const PlugIcon(), size: 12, color: color),
                const SizedBox(width: 6),
                ClideText(label, fontSize: clideFontCaption, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}
