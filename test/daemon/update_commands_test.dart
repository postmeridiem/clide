/// `app.update` (T-621, D-113): check, install, progress events, and the
/// windows restarting only after a successful install. The updater is the real
/// one over a temp install dir, with the download faked. Flutter-free.
@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/update_commands.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/panes/event_sink.dart';
import 'package:clide/src/update/self_update.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late DaemonDispatcher d;
  late RecordingEventSink events;
  late int restarts;
  late File tarball;
  late String sha;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('clide-app-update-');
    d = DaemonDispatcher();
    events = RecordingEventSink();
    restarts = 0;
    final src = Directory('${tmp.path}/src')..createSync();
    File('${src.path}/clide').writeAsStringSync('#!/bin/sh\n');
    await Process.run('chmod', ['755', '${src.path}/clide']);
    tarball = File('${tmp.path}/clide-linux-x64-2.99.0.tar.gz');
    await Process.run('tar', ['-C', src.path, '-czf', tarball.path, '.']);
    sha = '${(await Process.run('sha256sum', [tarball.path])).stdout}'.split(' ').first;
    Directory('${tmp.path}/lib/clide').createSync(recursive: true);
    File('${tmp.path}/lib/clide/clide').writeAsStringSync('old');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String latest({String? digest}) => jsonEncode({
    'tag_name': 'v2.99.0',
    'html_url': 'https://github.com/postmeridiem/clide/releases/tag/v2.99.0',
    'assets': [
      {
        'name': 'clide-linux-x64-2.99.0.tar.gz',
        'browser_download_url': 'https://example.test/t.tar.gz',
        'digest': 'sha256:${digest ?? sha}',
        'size': tarball.lengthSync(),
      },
    ],
  });

  void register({bool installable = true, String? digest, String current = '2.16.0'}) => registerUpdateCommands(
    d,
    events,
    repositoryUrl: 'https://github.com/postmeridiem/clide',
    currentVersion: current,
    updater: installable ? SelfUpdater(installDir: '${tmp.path}/lib/clide', download: (url, to, onChunk) async => tarball.copy(to.path)) : null,
    restartWindows: () async => restarts++,
    fetch: (_) async => latest(digest: digest),
    restartGrace: Duration.zero,
  );

  Future<IpcResponse> call([Map<String, Object?> args = const {}]) => d.dispatch(IpcRequest(id: '1', cmd: 'app.update', args: args));

  test('without --install it only reports what is available', () async {
    register();
    final r = await call();
    expect(r.ok, isTrue);
    expect(r.data, containsPair('latest', '2.99.0'));
    expect(r.data, containsPair('installable', true));
    expect(File('${tmp.path}/lib/clide/clide').readAsStringSync(), 'old', reason: 'nothing installed');
    expect(restarts, 0);
  });

  test('--install swaps the bundle, reports progress, then restarts the windows', () async {
    register();
    final r = await call({'install': true});
    expect(r.ok, isTrue, reason: '${r.error?.message}');
    expect(r.data, containsPair('restarting', true));
    expect(File('${tmp.path}/lib/clide.old/clide').readAsStringSync(), 'old');
    final phases = [for (final e in events.ofKind('app.update')) e.data['phase']];
    expect(phases.first, 'downloading');
    expect(phases.last, 'restarting');
    await Future<void>.delayed(Duration.zero);
    expect(restarts, 1);
  });

  test('a failed verification reports it and restarts nothing', () async {
    register(digest: '0000');
    final r = await call({'install': true});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('checksum mismatch'));
    expect(events.ofKind('app.update').last.data['phase'], 'failed');
    expect(File('${tmp.path}/lib/clide/clide').readAsStringSync(), 'old');
    await Future<void>.delayed(Duration.zero);
    expect(restarts, 0);
  });

  test('a development build cannot install, and says how to update', () async {
    register(installable: false);
    expect((await call()).data, containsPair('installable', false));
    final r = await call({'install': true});
    expect(r.ok, isFalse);
    expect(r.error!.message, contains('make install'));
  });

  test('up to date: nothing to install', () async {
    register(current: '2.99.0');
    final r = await call({'install': true});
    expect(r.ok, isTrue);
    expect(r.data, containsPair('available', false));
    expect(restarts, 0);
  });
}
