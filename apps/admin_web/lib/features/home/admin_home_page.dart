import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Início do painel administrativo depois de login + MFA verificados.
///
/// Só os módulos já construídos aparecem, e só para quem tem o papel
/// certo (docs/12 seção 12: "nenhum operador acessa módulo fora de seu
/// papel") — notificações e suporte ainda não existem (ver
/// docs/IMPLEMENTATION_STATUS.md, "Próxima ação").
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key, required this.role});

  final AdminRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.kidsTaskTokens;
    final canSeeSubscriptions =
        role == AdminRole.superAdmin || role == AdminRole.billing;
    final canSeeFamilies =
        role == AdminRole.superAdmin || role == AdminRole.support;
    final canSeeThemes =
        role == AdminRole.superAdmin || role == AdminRole.content;

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Conectado como ${_roleLabel(role)}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (canSeeSubscriptions)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Assinaturas'),
                      subtitle: const Text(
                        'Buscar família, ver plano efetivo e conceder/'
                        'revogar override de suporte',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/subscriptions'),
                    ),
                  ),
                if (canSeeFamilies)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.family_restroom_outlined),
                      title: const Text('Famílias e usuários'),
                      subtitle: const Text(
                        'Buscar família, ver responsáveis/crianças/'
                        'aparelhos/consentimentos e alterar status',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/families'),
                    ),
                  ),
                if (canSeeThemes)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Temas e conteúdo'),
                      subtitle: const Text(
                        'Catálogo de temas (rascunho/publicar/retirar) e '
                        'fila de solicitações Premium de tema',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin/themes'),
                    ),
                  ),
                if (!canSeeSubscriptions && !canSeeFamilies && !canSeeThemes)
                  const Text(
                    'Nenhum módulo disponível para o seu papel ainda — '
                    'notificações e suporte chegam em próximas fatias.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
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
