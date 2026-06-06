import 'package:clide/kernel/src/fuzzy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fuzzyScore', () {
    test('empty query scores 0 (matches anything)', () {
      expect(fuzzyScore('anything', ''), 0);
    });

    test('returns null when query is not a subsequence', () {
      expect(fuzzyScore('git commit', 'xyz'), isNull);
      expect(fuzzyScore('abc', 'abcd'), isNull); // query longer / extra char
    });

    test('matches non-contiguous subsequences', () {
      expect(fuzzyScore('git commit', 'gc'), isNotNull);
      expect(fuzzyScore('theme pick', 'tp'), isNotNull);
    });

    test('lower score is better: contiguous + early beats gappy + late', () {
      final contiguousEarly = fuzzyScore('abcxxxx', 'abc')!; // match at 0,1,2
      final gappyLate = fuzzyScore('xxxxabc', 'abc')!; // starts at 4
      expect(contiguousEarly, lessThan(gappyLate));

      final tight = fuzzyScore('ab', 'ab')!; // adjacent
      final spread = fuzzyScore('axb', 'ab')!; // a gap between a and b
      expect(tight, lessThan(spread));
    });

    test('case sensitivity is the caller\'s responsibility', () {
      expect(fuzzyScore('GIT', 'git'), isNull); // differing case → no match
      expect(fuzzyScore('GIT'.toLowerCase(), 'git'), isNotNull);
    });
  });
}
