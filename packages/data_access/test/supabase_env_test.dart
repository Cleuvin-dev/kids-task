import 'package:data_access/data_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SupabaseEnv.fromDartDefine lança StateError sem --dart-define', () {
    expect(() => SupabaseEnv.fromDartDefine(), throwsStateError);
  });

  test('SupabaseEnv guarda url e publishableKey informados', () {
    const env = SupabaseEnv(
      url: 'https://example.supabase.co',
      publishableKey: 'key',
    );
    expect(env.url, 'https://example.supabase.co');
    expect(env.publishableKey, 'key');
  });
}
