import 'package:clide/clide.dart' show IpcResponse;
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';

import 'about_dialog.dart';
import 'file_actions.dart';
import 'menu_model.dart';

/// Application-menu extension (T-48). Registers the File/Help commands the menu
/// bar invokes (View commands already exist elsewhere) and owns the curated
/// menu tree. Constructed with [KernelServices] — like `ViewExtension` — because
/// the File actions need window/project/panels/dialog, which the extension
/// context doesn't expose.
class MenuBarExtension extends ClideExtension {
  MenuBarExtension({required this.services});

  final KernelServices services;
  late final FileActions _file = FileActions(services);

  @override
  String get id => 'builtin.menubar';
  @override
  String get title => 'Application Menu';
  @override
  String get version => '0.1.0';

  @override
  List<ContributionPoint> get contributions => [
        CommandContribution(
          id: 'file.openFolder',
          command: 'file.openFolder',
          title: 'File: Open Folder…',
          run: (_) async {
            await _file.openFolder();
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
        CommandContribution(
          id: 'file.newWindow',
          command: 'file.newWindow',
          title: 'File: New Window',
          run: (_) async {
            _file.newWindow();
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
        CommandContribution(
          id: 'file.closeWorkspace',
          command: 'file.closeWorkspace',
          title: 'File: Close Project',
          run: (_) async {
            _file.closeWorkspace();
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
        CommandContribution(
          id: 'help.about',
          command: 'help.about',
          title: 'Help: About clide',
          run: (_) async {
            services.dialog.show<Object>((ctx, dismiss) => AboutDialog(onDismiss: () => dismiss()));
            return IpcResponse.ok(id: '', data: const {});
          },
        ),
      ];
}

/// The curated File / View / Help tree (T-48). View ends with a `view.*`
/// auto-fill so newly-registered view commands surface without edits here.
List<TopMenu> buildClideMenuTree() => [
      TopMenu(title: 'File', mnemonic: 0, nodes: [
        const MenuCommandItem('file.openFolder', fallbackTitle: 'Open Folder…'),
        const MenuCommandItem('file.newWindow', fallbackTitle: 'New Window'),
        const MenuSeparator(),
        MenuCommandItem('file.closeWorkspace', fallbackTitle: 'Close Project', enabledWhen: (s) => s.project.isOpen),
      ]),
      TopMenu(title: 'View', mnemonic: 0, nodes: const [
        MenuCommandItem('view.zoomIn'),
        MenuCommandItem('view.zoomOut'),
        MenuCommandItem('view.zoomReset'),
        MenuSeparator(),
        MenuCommandItem('sidebar.collapse'),
        MenuCommandItem('context.collapse'),
        MenuCommandItem('dock.toggle'),
        MenuCommandItem('panel.focusMode'),
        MenuSeparator(),
        MenuAutoFill('view.'),
      ]),
      TopMenu(title: 'Help', mnemonic: 0, nodes: const [
        MenuCommandItem('help.about', fallbackTitle: 'About clide'),
      ]),
    ];
