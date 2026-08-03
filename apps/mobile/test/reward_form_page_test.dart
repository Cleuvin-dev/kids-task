import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/guardian_rewards/reward_form_page.dart';

void main() {
  testWidgets('exige título antes de salvar', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RewardFormPage(familyId: 'family-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Informe o título'), findsOneWidget);
  });
}
