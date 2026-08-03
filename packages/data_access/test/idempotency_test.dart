import 'package:data_access/data_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newIdempotencyKey gera um UUID v4 bem formado', () {
    final key = newIdempotencyKey();
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(pattern.hasMatch(key), isTrue, reason: key);
  });

  test('newIdempotencyKey gera valores diferentes a cada chamada', () {
    final keys = List.generate(20, (_) => newIdempotencyKey());
    expect(keys.toSet(), hasLength(20));
  });
}
