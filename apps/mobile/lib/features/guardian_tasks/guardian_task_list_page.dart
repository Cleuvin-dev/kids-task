import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

const _periodLabels = {
  'morning': 'Manhã',
  'afternoon_evening': 'Tarde/Noite',
  'anytime': 'Qualquer horário',
};

/// Lista de tarefas de uma criança: criar, editar, pausar/retomar e
/// arquivar (docs/04 seção 12).
class GuardianTaskListPage extends ConsumerStatefulWidget {
  const GuardianTaskListPage({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<GuardianTaskListPage> createState() =>
      _GuardianTaskListPageState();
}

class _GuardianTaskListPageState extends ConsumerState<GuardianTaskListPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tasks = const [];

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
      final tasks = await ref
          .read(taskRepositoryProvider)
          .listTasksForChild(widget.childId);
      setState(() => _tasks = tasks);
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar as tarefas agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNew() async {
    final saved = await context.push<bool>(
      '/guardian/tasks/new',
      extra: {'childId': widget.childId},
    );
    if (saved == true) _load();
  }

  Future<void> _fromTemplate() async {
    final saved = await context.push<bool>(
      '/guardian/tasks/templates',
      extra: {'childId': widget.childId},
    );
    if (saved == true) _load();
  }

  Future<void> _edit(Map<String, dynamic> task) async {
    final schedule = await ref
        .read(taskRepositoryProvider)
        .fetchActiveSchedule(task['id'] as String);
    if (!mounted) return;
    final saved = await context.push<bool>(
      '/guardian/tasks/${task['id']}/edit',
      extra: {'childId': widget.childId, 'task': task, 'schedule': schedule},
    );
    if (saved == true) _load();
  }

  Future<void> _pause(String taskId) async {
    try {
      await ref.read(taskRepositoryProvider).pauseTask(taskId);
      _load();
    } catch (_) {
      _showError('Não foi possível pausar a tarefa agora.');
    }
  }

  Future<void> _resume(String taskId) async {
    try {
      await ref.read(taskRepositoryProvider).resumeTask(taskId);
      _load();
    } catch (_) {
      _showError('Não foi possível retomar a tarefa agora.');
    }
  }

  Future<void> _archive(String taskId) async {
    try {
      await ref.read(taskRepositoryProvider).archiveTask(taskId);
      _load();
    } catch (_) {
      _showError('Não foi possível arquivar a tarefa agora.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas'),
        actions: [
          IconButton(
            onPressed: _fromTemplate,
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Usar catálogo',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNew,
        child: const Icon(Icons.add),
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
                  if (_tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Nenhuma tarefa cadastrada ainda.'),
                      ),
                    ),
                  ..._tasks.map(_buildTaskCard),
                ],
              ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isActive = task['is_active'] as bool? ?? true;
    final isBonus = task['is_bonus'] as bool? ?? false;
    final period = task['period'] as String? ?? 'anytime';
    final coinReward = task['coin_reward'] as int? ?? 0;

    return Card(
      child: ListTile(
        leading: Icon(
          isBonus ? Icons.star_outline : Icons.checklist_outlined,
          color: isActive ? null : Theme.of(context).disabledColor,
        ),
        title: Text(task['title'] as String),
        subtitle: Text(
          '${_periodLabels[period] ?? period} · $coinReward KidsCoins'
          '${isActive ? '' : ' · pausada'}',
        ),
        onTap: () => _edit(task),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            final taskId = task['id'] as String;
            switch (action) {
              case 'pause':
                _pause(taskId);
              case 'resume':
                _resume(taskId);
              case 'archive':
                _archive(taskId);
            }
          },
          itemBuilder: (context) => [
            if (isActive)
              const PopupMenuItem(value: 'pause', child: Text('Pausar'))
            else
              const PopupMenuItem(value: 'resume', child: Text('Retomar')),
            const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
          ],
        ),
      ),
    );
  }
}
