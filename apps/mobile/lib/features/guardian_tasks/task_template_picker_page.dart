import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Catálogo de tarefas prontas do responsável (docs/17). Escolher um
/// template pré-preenche o formulário de criação; a tarefa da família
/// nunca fica sincronizada com o template depois.
class TaskTemplatePickerPage extends ConsumerStatefulWidget {
  const TaskTemplatePickerPage({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<TaskTemplatePickerPage> createState() =>
      _TaskTemplatePickerPageState();
}

class _TaskTemplatePickerPageState
    extends ConsumerState<TaskTemplatePickerPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _templates = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await ref
          .read(taskTemplateRepositoryProvider)
          .listTemplates();
      setState(() => _templates = templates);
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar o catálogo agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _use(Map<String, dynamic> template) async {
    final saved = await context.push<bool>(
      '/guardian/tasks/new',
      extra: {'childId': widget.childId, 'template': template},
    );
    if (saved == true && mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de tarefas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  AsyncErrorBanner(message: _errorMessage!),
                ..._templates.map(
                  (template) => Card(
                    child: ListTile(
                      title: Text(template['title'] as String),
                      subtitle: Text(
                        '${template['category']} · '
                        '${template['suggested_age_min']}-'
                        '${template['suggested_age_max']} anos'
                        '${(template['requires_supervision'] as bool? ?? false) ? ' · supervisão recomendada' : ''}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _use(template),
                        child: const Text('Usar'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
