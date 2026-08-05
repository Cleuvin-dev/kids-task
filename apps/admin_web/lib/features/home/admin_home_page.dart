import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Início do painel administrativo depois de login + MFA verificados.
///
/// Só a fundação nesta fatia (docs/12): sem dashboard, famílias, conteúdo,
/// assinaturas nem suporte ainda — cada um chega numa fatia futura do
/// Marco 7 (ver docs/IMPLEMENTATION_STATUS.md, "Próxima ação").
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key, required this.role});

  final AdminRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.kidsTaskTokens;
    return Scaffold(
      backgroundColor: tokens.colorBackground,
      appBar: AppBar(
        title: const Text('Painel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(adminAuthRepositoryProvider).signOut();
              ref.invalidate(adminResolvedSessionProvider);
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Conectado como ${_roleLabel(role)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Login e verificação em duas etapas concluídos. Os módulos '
                'do painel (famílias, conteúdo, assinaturas, notificações e '
                'suporte) chegam nas próximas fatias do Marco 7.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(AdminRole role) => switch (role) {
    AdminRole.superAdmin => 'administrador geral',
    AdminRole.support => 'suporte',
    AdminRole.content => 'conteúdo',
    AdminRole.billing => 'faturamento',
  };
}
