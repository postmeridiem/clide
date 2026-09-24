import 'dart:convert';
import 'dart:io';

import 'package:clide/src/broker/cli.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/location.dart';
import 'package:clide/src/broker/store/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late Map<String, String> environment;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('clide-broker-cli-');
    environment = {'CLIDE_BROKER_STORE': 'sqlite:${dir.path}/broker.db'};
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(int, String, String)> run(List<String> args) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runBrokerCli(args, environment: environment, out: out, err: err);
    return (code, out.toString(), err.toString());
  }

  test('without CLIDE_BROKER_STORE it refuses and names the variable', () async {
    environment = {};
    final (code, out, err) = await run(['settings', 'list']);
    expect([code, out], [exitConfig, '']);
    expect(err, contains('CLIDE_BROKER_STORE is not set'));
  });

  test('sets, gets, lists and unsets a setting', () async {
    expect((await run(['settings', 'set', 'public_origin', 'https://clide.example.com'])).$1, 0);
    expect(await run(['settings', 'get', 'public_origin']), (0, 'https://clide.example.com\n', ''));
    expect((await run(['settings', 'list'])).$2, matches(RegExp(r'public_origin +https://clide\.example\.com +store')));
    expect((await run(['settings', 'unset', 'public_origin'])).$1, 0);
    final (code, _, err) = await run(['settings', 'get', 'public_origin']);
    expect([code, err], [1, 'public_origin is not set.\n']);
  });

  test('unset says when there was nothing stored, and refuses a secret', () async {
    expect(await run(['settings', 'unset', 'signin.mode']), (0, '', 'signin.mode had no stored value.\n'));
    final (code, _, err) = await run(['settings', 'unset', 'oidc.client_secret']);
    expect(code, exitData);
    expect(err, contains('never stored'));
  });

  test('lists where each value came from, and never prints a secret', () async {
    environment['CLIDE_BROKER_OIDC_CLIENT_SECRET'] = 'hunter2';
    environment['CLIDE_BROKER_SIGNIN_MODE'] = 'oidc';
    final (_, text, _) = await run(['settings', 'list']);
    expect(text, isNot(contains('hunter2')));
    expect(text, matches(RegExp(r'oidc\.client_secret +\(set\) +environment \(CLIDE_BROKER_OIDC_CLIENT_SECRET\)')));
    expect(text, matches(RegExp(r'signin\.mode +oidc +environment \(CLIDE_BROKER_SIGNIN_MODE\)')));
    expect(text, matches(RegExp(r'session\.lifetime_hours +336 +default')));

    final (_, json, _) = await run(['settings', 'list', '--json']);
    expect(json, isNot(contains('hunter2')));
    final secret = (jsonDecode(json) as List).cast<Map<String, Object?>>().singleWhere((s) => s['key'] == 'oidc.client_secret');
    expect(secret, containsPair('value', null));
    expect(secret, containsPair('set', true));
  });

  test('get refuses to print a secret', () async {
    environment['CLIDE_BROKER_OIDC_CLIENT_SECRET'] = 'hunter2';
    final (code, out, err) = await run(['settings', 'get', 'oidc.client_secret']);
    expect([code, out], [exitUsage, '']);
    expect(err, isNot(contains('hunter2')));
  });

  test('set refuses a secret and names the variable to use instead', () async {
    final (code, _, err) = await run(['settings', 'set', 'oidc.client_secret', 'hunter2']);
    expect(code, exitData);
    expect(err, contains('CLIDE_BROKER_OIDC_CLIENT_SECRET'));
  });

  test('set refuses an invalid value', () async {
    final (code, _, err) = await run(['settings', 'set', 'signin.mode', 'basic']);
    expect(code, exitData);
    expect(err, contains('token or oidc'));
  });

  test('set says when an environment variable hides the stored value', () async {
    environment['CLIDE_BROKER_SIGNIN_MODE'] = 'oidc';
    final (code, _, err) = await run(['settings', 'set', 'signin.mode', 'token']);
    expect(code, 0);
    expect(err, contains('CLIDE_BROKER_SIGNIN_MODE overrides it'));
  });

  test('a bad value in the environment is reported by get', () async {
    environment['CLIDE_BROKER_SIGNIN_MODE'] = 'basic';
    final (code, _, err) = await run(['settings', 'get', 'signin.mode']);
    expect(code, exitConfig);
    expect(err, contains('token or oidc'));
  });

  test('refuses an unknown command, key or argument count, and prints usage for help', () async {
    expect((await run([])).$1, exitUsage);
    expect((await run(['serve-all'])).$1, exitUsage);
    expect((await run(['settings', 'get', 'signin.method'])).$3, contains('no setting "signin.method"'));
    expect((await run(['settings', 'set', 'signin.mode'])).$1, exitUsage);
    expect((await run(['settings', 'list', '--yaml'])).$1, exitUsage);
    final (code, out, _) = await run(['help']);
    expect([code, out], [0, contains('Usage: clide_broker')]);
  });

  test('refuses a store whose schema is newer than this broker', () async {
    await (await BrokerStore.open(SqliteLocation('${dir.path}/broker.db'))).close();
    final db = SqliteDatabase.open('${dir.path}/broker.db');
    db.execute('INSERT INTO broker_schema (version) VALUES (?1)', [BrokerStore.schemaVersion + 1]);
    db.close();
    final (code, _, err) = await run(['settings', 'list']);
    expect(code, exitConfig);
    expect(err, contains('Run a newer broker'));
  });

  test('a store that cannot be opened is reported, not thrown', () async {
    environment['CLIDE_BROKER_STORE'] = 'sqlite:${dir.path}/no/such/dir/broker.db';
    final (code, _, err) = await run(['settings', 'list']);
    expect(code, exitUnavailable);
    expect(err, contains('cannot be opened'));
  });
}
