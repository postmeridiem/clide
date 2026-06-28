import 'package:clide/src/svg/svg_color.dart';
import 'package:test/test.dart';

void main() {
  group('parseSvgColor', () {
    test('#rrggbb', () {
      expect(parseSvgColor('#0D32B2'), 0xFF0D32B2);
    });

    test('#rgb shorthand expands each nibble', () {
      expect(parseSvgColor('#abc'), 0xFFAABBCC);
    });

    test('#rrggbbaa carries alpha', () {
      expect(parseSvgColor('#11223344'), 0x44112233);
    });

    test('#rgba shorthand', () {
      expect(parseSvgColor('#1234'), 0x44112233);
    });

    test('rgb() integer channels', () {
      expect(parseSvgColor('rgb(13, 50, 178)'), 0xFF0D32B2);
    });

    test('rgba() with fractional alpha', () {
      expect(parseSvgColor('rgba(0,0,0,0.5)'), 0x80000000);
    });

    test('rgb() percentage channels', () {
      expect(parseSvgColor('rgb(100%, 0%, 0%)'), 0xFFFF0000);
    });

    test('named colours', () {
      expect(parseSvgColor('red'), 0xFFFF0000);
      expect(parseSvgColor('white'), 0xFFFFFFFF);
      expect(parseSvgColor('grey'), parseSvgColor('gray'));
    });

    test('none and transparent are fully transparent', () {
      expect(parseSvgColor('none'), 0x00000000);
      expect(parseSvgColor('transparent'), 0x00000000);
    });

    test('case-insensitive and whitespace-tolerant', () {
      expect(parseSvgColor('  #0d32b2 '), 0xFF0D32B2);
      expect(parseSvgColor('RED'), 0xFFFF0000);
    });

    test('unrecognised input is null, never throws', () {
      expect(parseSvgColor(''), isNull);
      expect(parseSvgColor('bogus'), isNull);
      expect(parseSvgColor('#xyz'), isNull);
      expect(parseSvgColor('#12'), isNull);
    });
  });
}
