import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'context.kidsTaskTokens usa fallback quando o tema não define tokens',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(capturedContext.kidsTaskTokens, KidsTaskTokens.fallback);
    },
  );

  test('lerp entre dois conjuntos de tokens não lança erro', () {
    final a = KidsTaskTokens.fallback;
    final b = a.copyWith(colorPrimary: const Color(0xFF000000));
    final mid = a.lerp(b, 0.5);
    expect(mid, isA<KidsTaskTokens>());
  });
}
