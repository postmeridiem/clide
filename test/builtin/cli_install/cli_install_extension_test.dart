/// T-212: the cli-install extension wires the Flutter-free [CliInstaller] to
/// a palette/CLI command and proactive launch-time notifications.
library;

import 'dart:io';

import 'package:clide/builtin/cli_install/cli_install.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/cli_install.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  late Directory tmp;

  setUp(() async {
    f = await KernelFixture.create();
    tmp = Directory.systemTemp.createTempSync('clide_cli_ext_');
  });
  tearDown(() async {
    await f.dispose();
    tmp.deleteSync(recursive: true);
  });

  File touchExec(String path, {String contents = '#!/bin/sh\n'}) {
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
    if (!Platform.isWindows) Process.runSync('chmod', ['755', path]);
    return file;
  }

  /// Register + activate the extension with an injected installer.
  Future<void> boot(CliInstaller installer) async {
    f.services.extensions.register(CliInstallExtension(installer: installer));
    await f.services.extensions.activate('builtin.cli-install');
  }

  test('identifies itself', () {
    final ext = CliInstallExtension();
    expect(ext.id, 'builtin.cli-install');
    expect(ext.title, 'CLI Install');
    expect(ext.version, '0.1.0');
  });

  test('contributes the install command', () async {
    await boot(CliInstaller(
      resolvedExecutable: '${tmp.path}/gui/clide',
      env: {'PATH': '${tmp.path}/bin'},
      bundledClientCandidates: const [],
      installDir: '${tmp.path}/bin',
    ));
    expect(f.services.commands.get('clide.installCli'), isNotNull);
  });

  test('warns on activation when clide is missing from PATH', () async {
    await boot(CliInstaller(
      resolvedExecutable: '${tmp.path}/gui/clide',
      env: {'PATH': '${tmp.path}/empty'},
      bundledClientCandidates: const [],
      installDir: '${tmp.path}/bin',
    ));
    final notes = f.services.notify.active;
    expect(notes, isNotEmpty);
    expect(notes.first.level, NotificationLevel.warning);
    expect(notes.first.title, 'clide CLI not installed');
  });

  test('warns on activation when clide is a stale GUI symlink', () async {
    final gui = touchExec('${tmp.path}/gui/clide').path;
    final binDir = Directory('${tmp.path}/bin')..createSync();
    Link('${binDir.path}/clide').createSync(gui); // PATH clide → the GUI
    await boot(CliInstaller(
      resolvedExecutable: gui,
      env: {'PATH': binDir.path},
      bundledClientCandidates: const [],
      installDir: binDir.path,
    ));
    final notes = f.services.notify.active;
    expect(notes, isNotEmpty);
    expect(notes.first.level, NotificationLevel.warning);
    expect(notes.first.title, 'clide CLI is stale');
  });

  test('does not warn when clide is already installed', () async {
    final binDir = Directory('${tmp.path}/bin')..createSync();
    touchExec('${binDir.path}/clide');
    await boot(CliInstaller(
      resolvedExecutable: '${tmp.path}/gui/clide',
      env: {'PATH': binDir.path},
      bundledClientCandidates: const [],
      installDir: binDir.path,
    ));
    expect(f.services.notify.active, isEmpty);
  });

  test('running the command installs the client and reports success', () async {
    final src = touchExec('${tmp.path}/bundle/clide-cli');
    final binDir = '${tmp.path}/bin';
    await boot(CliInstaller(
      resolvedExecutable: '${tmp.path}/gui/clide',
      env: {'PATH': binDir},
      bundledClientCandidates: [src.path],
      installDir: binDir,
    ));
    final r = await f.services.commands.execute('clide.installCli');
    expect(r.ok, isTrue);
    expect(r.data['installed'], '$binDir/clide');
    expect(File('$binDir/clide').existsSync(), isTrue);
    expect(
      f.services.notify.active.any((n) => n.level == NotificationLevel.success && n.title == 'clide CLI installed'),
      isTrue,
    );
  });

  test('running the command surfaces a tool error when nothing to install', () async {
    await boot(CliInstaller(
      resolvedExecutable: '${tmp.path}/gui/clide',
      env: {'PATH': '${tmp.path}/bin'},
      bundledClientCandidates: const [],
      installDir: '${tmp.path}/bin',
    ));
    final r = await f.services.commands.execute('clide.installCli');
    expect(r.ok, isFalse);
    expect(r.error!.kind, IpcErrorKind.toolError);
    expect(
      f.services.notify.active.any((n) => n.level == NotificationLevel.error),
      isTrue,
    );
  });
}
