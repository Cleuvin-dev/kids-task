import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Dashboard de métricas agregadas (docs/12 seção 3) — só `super_admin`,
/// nunca nome de criança, só contagens.
///
/// "Falhas de push/jobs/webhooks" fica fora: não existe rastreamento de
/// falha de `pg_cron` nem de webhook de loja numa tabela consultável, e
/// push de verdade continua bloqueado (Marco 6). Melhor faltar do que
/// fingir uma métrica zero.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _metrics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final metrics = await ref
          .read(adminDashboardRepositoryProvider)
          .fetchMetrics();
      setState(() {
        _metrics = metrics;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar as métricas agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log de auditoria',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/admin/audit-log'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (metrics == null)
                    const Text('Sem dados.')
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        _metricCard(
                          'Famílias totais',
                          '${metrics['families_total']}',
                        ),
                        _metricCard(
                          'Famílias ativas',
                          '${metrics['families_active']}',
                        ),
                        _metricCard(
                          'Onboarding concluído',
                          '${metrics['families_onboarded']}',
                        ),
                        _metricCard(
                          'Responsáveis',
                          '${metrics['guardians_total']}',
                        ),
                        _metricCard('Crianças', '${metrics['children_total']}'),
                        _metricCard(
                          'Gratuito x Premium',
                          '${(metrics['families_by_effective_plan'] as Map?)?['free'] ?? 0} x '
                              '${(metrics['families_by_effective_plan'] as Map?)?['premium'] ?? 0}',
                        ),
                        _metricCard(
                          'Tarefas ativas',
                          '${metrics['tasks_active']}',
                        ),
                        _metricCard(
                          'Aprovações pendentes',
                          '${metrics['occurrences_awaiting_approval']}',
                        ),
                        _metricCard(
                          'Tarefas concluídas (total)',
                          '${metrics['occurrences_approved_total']}',
                        ),
                        _metricCard(
                          'Resgates pendentes',
                          '${metrics['redemptions_pending']}',
                        ),
                        _metricCard(
                          'Resgates entregues (total)',
                          '${metrics['redemptions_delivered_total']}',
                        ),
                        _metricCard(
                          'Tickets abertos',
                          '${metrics['support_tickets_open']}',
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Falhas de push/jobs/webhooks não aparecem aqui — sem '
                    'infraestrutura de rastreamento ainda (ver '
                    'docs/IMPLEMENTATION_STATUS.md).',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
