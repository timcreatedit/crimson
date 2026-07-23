import 'dart:convert';

import 'package:crimson/crimson.dart';
import 'package:test/test.dart';

void main() {
  test('runtime and generated-code hashes match on every platform', () {
    for (final value in ['name', 'created_at', 'emoji 😀']) {
      final crimson = Crimson(utf8.encode('"$value"'));
      final safeCrimson = Crimson(utf8.encode('{"$value":null}'));

      expect(crimson.readStringHash(), Crimson.hash(value));
      expect(safeCrimson.iterObjectSafeHash(), Crimson.safeHash(value));
      expect(Crimson.safeHash(value), lessThanOrEqualTo(9007199254740991));
    }
  });
}
