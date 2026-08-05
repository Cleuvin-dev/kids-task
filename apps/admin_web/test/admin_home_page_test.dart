import 'package:admin_web/features/home/admin_home_page.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('só billing/super_admin veem o módulo Assinaturas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminHomePage(role: AdminRole.support)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assinaturas'), findsNothing);
  });

  testWidgets('billing vê o módulo Assinaturas', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminHomePage(role: AdminRole.billing)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assinaturas'), findsOneWidget);
  });

  testWidgets('só support/super_admin veem o módulo Famílias e usuários', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminHomePage(role: AdminRole.billing)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Famílias e usuários'), findsNothing);
  });

  testWidgets('support vê o módulo Famílias e usuários', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminHomePage(role: AdminRole.support)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Famílias e usuários'), findsOneWidget);
  });

  testWidgets('content não vê nenhum módulo e recebe a mensagem padrão', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AdminHomePage(role: AdminRole.content)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assinaturas'), findsNothing);
    expect(find.text('Famílias e usuários'), findsNothing);
    expect(find.textContaining('Nenhum módulo disponível'), findsOneWidget);
  });
}
