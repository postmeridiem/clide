import 'package:clide/src/broker/store/postgres/scram.dart';
import 'package:test/test.dart';

// The exchange in RFC 7677, section 3.
const _serverFirst = r'r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096';
const _clientFinal = r'c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=';
const _serverFinal = 'v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=';

ScramClient _rfcClient() => ScramClient('pencil', user: 'user', nonce: 'rOprNGfwEbeRWgbNEkqO');

Matcher _refusedWith(String part) => throwsA(isA<ScramException>().having((e) => e.message, 'message', contains(part)));

void main() {
  test("reproduces RFC 7677's exchange", () {
    final client = _rfcClient();
    expect(client.clientFirstMessage, 'n,,n=user,r=rOprNGfwEbeRWgbNEkqO');
    expect(client.clientFinalMessage(_serverFirst), _clientFinal);
    client.verifyServerFinal(_serverFinal);
  });

  test("refuses a server signature that is not the verifier's", () {
    final client = _rfcClient()..clientFinalMessage(_serverFirst);
    expect(() => client.verifyServerFinal('v=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='), _refusedWith('signature is wrong'));
    expect(() => client.verifyServerFinal('e=invalid-proof'), _refusedWith('refused the proof'));
  });

  test('refuses a final message before its proof was sent', () {
    expect(() => _rfcClient().verifyServerFinal(_serverFinal), _refusedWith('before the client sent its proof'));
  });

  test('refuses a server signature that is not base64', () {
    final client = _rfcClient()..clientFinalMessage(_serverFirst);
    expect(() => client.verifyServerFinal('v=***'), _refusedWith('not base64'));
  });

  test("refuses a server nonce that does not extend the client's", () {
    expect(() => _rfcClient().clientFinalMessage('r=someoneElse,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096'), _refusedWith('nonce'));
    expect(() => _rfcClient().clientFinalMessage('r=rOprNGfwEbeRWgbNEkqO,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096'), _refusedWith('nonce'));
  });

  test('refuses an iteration count outside its bounds, and a missing or broken salt', () {
    const nonce = 'r=rOprNGfwEbeRWgbNEkqOserver';
    expect(() => _rfcClient().clientFinalMessage('$nonce,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4095'), _refusedWith('iteration count'));
    expect(() => _rfcClient().clientFinalMessage('$nonce,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=1000001'), _refusedWith('iteration count'));
    expect(() => _rfcClient().clientFinalMessage('$nonce,s=W22ZaJ0SNY7soEsUEjb6gQ=='), _refusedWith('iteration count'));
    expect(() => _rfcClient().clientFinalMessage('$nonce,i=4096'), _refusedWith('no salt'));
    expect(() => _rfcClient().clientFinalMessage('$nonce,s=not*base64,i=4096'), _refusedWith('not base64'));
  });

  test('refuses a mandatory extension and a malformed attribute', () {
    expect(() => _rfcClient().clientFinalMessage('m=ext,r=rOprNGfwEbeRWgbNEkqOx,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096'), _refusedWith('extension'));
    expect(() => _rfcClient().clientFinalMessage('rOprNGfwEbeRWgbNEkqOx'), _refusedWith('malformed'));
  });

  test('escapes the user name and makes a fresh nonce each time', () {
    expect(ScramClient('p', user: 'a=b,c', nonce: 'n').clientFirstMessage, 'n,,n=a=3Db=2Cc,r=n');
    expect(ScramClient('p').clientFirstMessage, isNot(ScramClient('p').clientFirstMessage));
    expect(ScramClient('p').clientFirstMessage, startsWith('n,,n=,r='));
  });
}
