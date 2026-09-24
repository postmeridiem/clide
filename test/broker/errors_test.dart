import 'package:clide/src/broker/environment.dart';
import 'package:clide/src/broker/store/broker_store.dart';
import 'package:clide/src/broker/store/postgres/connection.dart';
import 'package:clide/src/broker/store/postgres/scram.dart';
import 'package:clide/src/broker/store/postgres/wire.dart';
import 'package:clide/src/broker/store/sqlite3.dart';
import 'package:test/test.dart';

/// The CLI and the store's own wrappers print these, so their text is part
/// of what an operator reads.
void main() {
  test('configuration and store errors print their message alone', () {
    expect(['${BrokerConfigException('Set X.')}', '${StoreSchemaException('Newer.')}', '${StoreUnavailableException('Down.')}'], ['Set X.', 'Newer.', 'Down.']);
  });

  test('engine errors name their kind, and their code when they have one', () {
    expect(
      [
        '${ScramException('bad')}',
        '${PostgresProtocolException('odd')}',
        '${PostgresConnectionException('lost')}',
        '${PostgresException('boom', code: '42601', detail: 'near x')}',
        '${PostgresException('boom')}',
        '${SqliteException('bad', code: 1, sql: 'SELEC')}',
        '${SqliteException('gone')}',
      ],
      [
        'ScramException: bad',
        'PostgresProtocolException: odd',
        'PostgresConnectionException: lost',
        'PostgresException(42601): boom (near x)',
        'PostgresException: boom',
        'SqliteException(1): bad\n  in: SELEC',
        'SqliteException: gone',
      ],
    );
  });
}
