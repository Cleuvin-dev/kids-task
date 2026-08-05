import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Busca de família para o módulo "Assinaturas" (docs/12 seção 5), por ID
/// da família ou e-mail do responsável — nunca por código familiar
/// (CLAUDE.md: "não enumerar famílias... a partir de tentativas de
/// código").
class AdminSubscriptionSearchPage extends ConsumerStatefulWidget {
  const AdminSubscriptionSearchPage({super.key});

  @override
  ConsumerState<AdminSubscriptionSearchPage> createState() =>
      _AdminSubscriptionSearchPageState();
}

class _AdminSubscriptionSearchPageState
    extends ConsumerState<AdminSubscriptionSearchPage> {
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
          .read(adminSubscriptionRepositoryProvider)
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
      appBar: AppBar(title: const Text('Assinaturas')),
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
          '${_planLabel(family['plan_code'] as String?)} · '
          '${guardianEmails.join(', ')} · '
          '${family['children_count']} criança(s)',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          '/admin/subscriptions/${family['family_id']}',
          extra: {'familyName': family['family_name']},
        ),
      ),
    );
  }
}

String _planLabel(String? planCode) => switch (planCode) {
  'premium' => 'Premium',
  'free' => 'Gratuito',
  _ => planCode ?? '—',
};
