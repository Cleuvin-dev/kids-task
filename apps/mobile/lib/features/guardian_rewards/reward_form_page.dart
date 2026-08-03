import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Criação/edição de recompensa (docs/05 seção 4). Sem regra de plano
/// nem agenda — bem mais simples que o formulário de tarefas.
class RewardFormPage extends ConsumerStatefulWidget {
  const RewardFormPage({
    super.key,
    required this.familyId,
    this.rewardId,
    this.initialReward,
  });

  final String familyId;
  final String? rewardId;
  final Map<String, dynamic>? initialReward;

  bool get isEditing => rewardId != null;

  @override
  ConsumerState<RewardFormPage> createState() => _RewardFormPageState();
}

class _RewardFormPageState extends ConsumerState<RewardFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costController;
  late final TextEditingController _cashEquivalentController;

  String? _childId;
  bool _loading = false;
  bool _loadingChildren = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _children = const [];

  @override
  void initState() {
    super.initState();
    final reward = widget.initialReward;
    _titleController = TextEditingController(
      text: reward?['title'] as String? ?? '',
    );
    _descriptionController = TextEditingController(
      text: reward?['description'] as String? ?? '',
    );
    _costController = TextEditingController(
      text: (reward?['cost_coins'] as int? ?? 0).toString(),
    );
    final cashCents = reward?['cash_equivalent_cents'] as int?;
    _cashEquivalentController = TextEditingController(
      text: cashCents == null ? '' : (cashCents / 100).toStringAsFixed(2),
    );
    _childId = reward?['child_id'] as String?;
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final children = await ref
          .read(childRepositoryProvider)
          .listChildren(widget.familyId);
      setState(() => _children = children);
    } catch (_) {
      // A tela ainda funciona com "toda a família" mesmo sem a lista.
    } finally {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _cashEquivalentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final cashText = _cashEquivalentController.text.trim();
      final cashCents = cashText.isEmpty
          ? null
          : (double.parse(cashText.replaceAll(',', '.')) * 100).round();

      if (widget.isEditing) {
        await ref
            .read(rewardRepositoryProvider)
            .updateReward(
              rewardId: widget.rewardId!,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              costCoins: int.parse(_costController.text),
              cashEquivalentCents: cashCents,
            );
      } else {
        await ref
            .read(rewardRepositoryProvider)
            .createReward(
              familyId: widget.familyId,
              childId: _childId,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              costCoins: int.parse(_costController.text),
              cashEquivalentCents: cashCents,
            );
      }
      if (mounted) context.pop(true);
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível salvar a recompensa agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar recompensa' : 'Nova recompensa'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null)
              AsyncErrorBanner(message: _errorMessage!),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe o título'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Custo em KidsCoins',
              ),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');
                return (parsed == null || parsed < 0)
                    ? 'Informe um número válido'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cashEquivalentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Equivalente em R\$ (opcional, só informativo)',
              ),
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: 16),
              const Text('Disponível para'),
              const SizedBox(height: 8),
              _loadingChildren
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String?>(
                      initialValue: _childId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Toda a família'),
                        ),
                        ..._children.map(
                          (child) => DropdownMenuItem(
                            value: child['id'] as String,
                            child: Text(
                              (child['nickname'] as String?) ??
                                  child['first_name'] as String,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _childId = value),
                    ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
