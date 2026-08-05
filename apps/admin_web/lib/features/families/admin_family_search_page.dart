import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Busca de família para o módulo "Famílias e usuários" (docs/12 seção 4),
/// por ID da família ou e-mail do responsável — mesma função
/// `admin_search_families` do módulo Assinaturas (fatia 3), reaproveitada
/// aqui num contexto diferente do painel.
class AdminFamilySearchPage extends ConsumerStatefulWidget {
  const AdminFamilySearchPage({super.key});

  @override
  ConsumerState<AdminFamilySearchPage> createState() =>
      _AdminFamilySearchPageState();
}

class _AdminFamilySearchPageState extends ConsumerState<AdminFamilySearchPage> {
  final _queryController = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 3) {
      setState(() => _errorMessage = 'Digite pelo menos 3 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await ref
          .read(adminFamilyRepositoryProvider)
          .searchFamilies(query);
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (_) {
      setState(() => _errorMessage = 'Não foi possível buscar agora.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Famílias e usuários')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              AsyncErrorBanner(message: _errorMessage!),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      labelText: 'ID da família ou e-mail do responsável',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _searched && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Nenhuma família encontrada.')),
              ),
            if (!_loading)
              Expanded(
                child: ListView(
                  children: _results.map(_buildResultCard).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> family) {
    final guardianEmails = List<String>.from(
      family['guardian_emails'] as List? ?? const [],
    );
    return Card(
      child: ListTile(
        title: Text(family['family_name'] as String),
        subtitle: Text(
          '${familyStatusLabel(family['status'] as String?)} · '
          '${_planLabel(family['plan_code'] as String?)} · '
          '${guardianEmails.join(', ')} · '
          '${family['children_count']} criança(s)',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/families/${family['family_id']}'),
      ),
    );
  }
}

String _planLabel(String? planCode) => switch (planCode) {
  'premium' => 'Premium',
  'free' => 'Gratuito',
  _ => planCode ?? '—',
};

/// Rótulo em pt-BR de `families.status` — reaproveitado pela tela de
/// detalhe também.
String familyStatusLabel(String? status) => switch (status) {
  'active' => 'Ativa',
  'restricted' => 'Restrita',
  'blocked' => 'Bloqueada',
  'deletion_pending' => 'Exclusão pendente',
  'deleted' => 'Excluída',
  _ => status ?? '—',
};
