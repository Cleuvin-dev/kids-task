import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Início real do responsável: família, código, membros e crianças
/// cadastradas (docs/07 seção 4.1). Tarefas, aprovações e recompensas
/// chegam nos próximos marcos — sem dados fictícios aqui.
class GuardianHomePage extends ConsumerStatefulWidget {
  const GuardianHomePage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<GuardianHomePage> createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends ConsumerState<GuardianHomePage> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _family;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _children = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final family = await ref
          .read(familyRepositoryProvider)
          .fetchFamily(widget.familyId);
      final members = await ref
          .read(familyRepositoryProvider)
          .listFamilyMembers(widget.familyId);
      final children = await ref
          .read(childRepositoryProvider)
          .listChildren(widget.familyId);
      setState(() {
        _family = family;
        _members = members;
        _children = children;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar sua família agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final email = await _promptForText(
      title: 'Convidar responsável',
      label: 'E-mail do convidado',
    );
    if (email == null || email.isEmpty) return;
    try {
      final invite = await ref
          .read(familyRepositoryProvider)
          .inviteGuardian(familyId: widget.familyId, email: email);
      if (!mounted) return;
      final message = invite.emailDelivery == 'sent'
          ? 'Convite enviado por e-mail.'
          : 'Convite criado. Envio automático de e-mail ainda não está '
                'configurado — compartilhe este link manualmente:\n${invite.inviteLink}';
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Convite criado'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível criar o convite agora.'),
          ),
        );
      }
    }
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addChild() async {
    context.push('/onboarding/child', extra: {'familyId': widget.familyId});
  }

  Future<void> _changeAppTheme() async {
    final current = _family?['guardian_theme'] as String? ?? 'blue';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tema do app'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('blue'),
            child: Row(
              children: [
                if (current == 'blue') const Icon(Icons.check, size: 18),
                if (current == 'blue') const SizedBox(width: 8),
                const Text('Azul'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('pink'),
            child: Row(
              children: [
                if (current == 'pink') const Icon(Icons.check, size: 18),
                if (current == 'pink') const SizedBox(width: 8),
                const Text('Rosa'),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await ref
          .read(familyRepositoryProvider)
          .updateGuardianTheme(familyId: widget.familyId, theme: selected);
      ref.invalidate(familyGuardianThemeProvider(widget.familyId));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível trocar o tema agora.'),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(guardianAuthRepositoryProvider).signOut();
    ref.invalidate(resolvedSessionProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(
            onPressed: () => context.push('/guardian/notifications'),
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificações',
          ),
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  _buildHeaderBanner(),
                  const SizedBox(height: 16),
                  _buildApprovalsCard(),
                  const SizedBox(height: 16),
                  _buildRewardsCard(),
                  const SizedBox(height: 16),
                  _buildThemeCard(),
                  const SizedBox(height: 16),
                  _buildFamilyCodeCard(),
                  const SizedBox(height: 16),
                  _buildMembersSection(),
                  const SizedBox(height: 16),
                  _buildChildrenSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    final familyName = _family?['name'] as String? ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(KidsTaskImages.dashboardBanner),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Text(
          familyName.isEmpty ? 'Sua família' : familyName,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildApprovalsCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Aprovações pendentes'),
        subtitle: const Text('Tarefas que a criança já enviou'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/guardian/approvals'),
      ),
    );
  }

  Widget _buildRewardsCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.card_giftcard_outlined),
        title: const Text('Recompensas'),
        subtitle: const Text('Catálogo e resgates das crianças'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/guardian/rewards'),
      ),
    );
  }

  Widget _buildThemeCard() {
    final current = _family?['guardian_theme'] as String? ?? 'blue';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: const Text('Tema do app'),
        subtitle: Text(current == 'pink' ? 'Rosa' : 'Azul'),
        trailing: TextButton(
          onPressed: _changeAppTheme,
          child: const Text('Trocar'),
        ),
      ),
    );
  }

  Widget _buildFamilyCodeCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.qr_code),
        title: const Text('Código da família'),
        subtitle: const Text(
          'Toque para gerar um novo código (invalida o atual)',
        ),
        onTap: () async {
          final code = await ref
              .read(familyRepositoryProvider)
              .rotateFamilyCode(widget.familyId);
          if (mounted) {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Novo código'),
                content: Text(code),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMembersSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Responsáveis'),
            trailing: TextButton(
              onPressed: _invite,
              child: const Text('Convidar'),
            ),
          ),
          ..._members.map((m) {
            final profile = m['profiles'] as Map<String, dynamic>?;
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(profile?['display_name'] as String? ?? '—'),
              subtitle: Text(
                (m['role'] as String) == 'owner'
                    ? 'Proprietário'
                    : 'Responsável',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChildrenSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Crianças'),
            trailing: TextButton(
              onPressed: _addChild,
              child: const Text('Adicionar'),
            ),
          ),
          if (_children.isEmpty)
            const ListTile(title: Text('Nenhuma criança cadastrada ainda.')),
          ..._children.map((child) {
            final avatar = childAvatarById(
              child['avatar_id'] as String? ?? 'default',
            );
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: avatar.color,
                child: Icon(avatar.icon, color: Colors.white),
              ),
              title: Text(
                (child['nickname'] as String?) ?? child['first_name'] as String,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.checklist_outlined),
                    tooltip: 'Tarefas',
                    onPressed: () =>
                        context.push('/guardian/children/${child['id']}/tasks'),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => context.push('/guardian/children/${child['id']}'),
            );
          }),
        ],
      ),
    );
  }
}
