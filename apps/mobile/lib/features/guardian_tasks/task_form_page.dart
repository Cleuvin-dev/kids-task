import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

const _weekdayLabels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// Criação/edição de tarefa. Um único formulário com campos condicionais
/// cobre os cinco tipos de agenda do docs/04 seção 2 (recorrente, data
/// única, bônus, sem horário, com prazo são combinações de flags sobre
/// once/recurring, não telas separadas).
class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({
    super.key,
    required this.childId,
    this.taskId,
    this.initialTask,
    this.initialSchedule,
    this.template,
  });

  final String childId;
  final String? taskId;
  final Map<String, dynamic>? initialTask;
  final Map<String, dynamic>? initialSchedule;
  final Map<String, dynamic>? template;

  bool get isEditing => taskId != null;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _coinRewardController;
  late final TextEditingController _xpRewardController;

  late TaskPeriod _period;
  late ApprovalMode _approvalMode;
  late LatePolicy _latePolicy;
  late bool _isBonus;
  late bool _isRequired;
  late ScheduleType _scheduleType;
  late Set<int> _weekdays;
  DateTime? _oneTimeDate;
  DateTime? _startsOn;
  DateTime? _endsOn;
  TimeOfDay? _startTime;
  TimeOfDay? _dueTime;

  String _iconKey = 'default';
  String _category = 'geral';

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    final schedule = widget.initialSchedule;
    final template = widget.template;

    _titleController = TextEditingController(
      text: (task?['title'] ?? template?['title']) as String? ?? '',
    );
    _descriptionController = TextEditingController(
      text: task?['description'] as String? ?? '',
    );
    _coinRewardController = TextEditingController(
      text: (task?['coin_reward'] as int? ?? 0).toString(),
    );
    _xpRewardController = TextEditingController(
      text: (task?['xp_reward_default'] as int? ?? 0).toString(),
    );

    _iconKey =
        (task?['icon_key'] ?? template?['icon_key']) as String? ?? 'default';
    _category =
        (task?['category'] ?? template?['category']) as String? ?? 'geral';

    _period = TaskPeriod.fromWireName(
      (task?['period'] ?? template?['suggested_period']) as String? ??
          'anytime',
    );
    _approvalMode = ApprovalMode.fromWireName(
      task?['approval_mode'] as String? ?? 'automatic',
    );
    _latePolicy = LatePolicy.fromWireName(
      task?['late_policy'] as String? ?? 'allow_late',
    );
    _isBonus = task?['is_bonus'] as bool? ?? false;
    _isRequired = task?['is_required'] as bool? ?? !_isBonus;

    _scheduleType = ScheduleType.fromWireName(
      schedule?['schedule_type'] as String? ?? 'recurring',
    );
    final weekdays = schedule?['weekdays'] as List?;
    _weekdays = weekdays != null
        ? weekdays.map((w) => w as int).toSet()
        : {1, 2, 3, 4, 5};
    _oneTimeDate = _parseDate(schedule?['one_time_date'] as String?);
    _startsOn = _parseDate(schedule?['starts_on'] as String?);
    _endsOn = _parseDate(schedule?['ends_on'] as String?);
    _startTime = _parseTime(schedule?['start_time'] as String?);
    _dueTime = _parseTime(schedule?['due_time'] as String?);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coinRewardController.dispose();
    _xpRewardController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.parse(value);

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _timeOnly(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduleType == ScheduleType.once && _oneTimeDate == null) {
      setState(() => _errorMessage = 'Escolha a data desta tarefa.');
      return;
    }
    if (_scheduleType == ScheduleType.recurring && _weekdays.isEmpty) {
      setState(() => _errorMessage = 'Escolha ao menos um dia da semana.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(taskRepositoryProvider)
          .upsertTask(
            taskId: widget.taskId,
            childId: widget.childId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            iconKey: _iconKey,
            category: _category,
            period: _period.wireName,
            isBonus: _isBonus,
            isRequired: _isRequired,
            coinReward: int.parse(_coinRewardController.text),
            xpRewardDefault: int.parse(_xpRewardController.text),
            approvalMode: _approvalMode.wireName,
            latePolicy: _latePolicy.wireName,
            scheduleType: _scheduleType.wireName,
            oneTimeDate: _scheduleType == ScheduleType.once
                ? _oneTimeDate
                : null,
            weekdays: _scheduleType == ScheduleType.recurring
                ? _weekdays.toList()
                : null,
            startsOn: _scheduleType == ScheduleType.recurring
                ? _startsOn
                : null,
            endsOn: _scheduleType == ScheduleType.recurring ? _endsOn : null,
            startTime: _startTime == null ? null : _timeOnly(_startTime!),
            dueTime: _dueTime == null ? null : _timeOnly(_dueTime!),
          );
      if (mounted) context.pop(true);
    } on DomainFailure catch (e) {
      setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      setState(() => _errorMessage = 'Não foi possível salvar a tarefa agora.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyMessage(DomainFailure e) {
    if (e.code == DomainErrorCode.planDailyTaskLimit) {
      return 'Isso ultrapassaria o limite de tarefas por dia do plano '
          'atual. Pause ou substitua outra tarefa antes de continuar.';
    }
    return e.message ?? 'Não foi possível salvar a tarefa agora.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar tarefa' : 'Nova tarefa'),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _coinRewardController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'KidsCoins'),
                    validator: _nonNegativeIntValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _xpRewardController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'XP'),
                    validator: _nonNegativeIntValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Período'),
            const SizedBox(height: 8),
            SegmentedButton<TaskPeriod>(
              segments: const [
                ButtonSegment(value: TaskPeriod.morning, label: Text('Manhã')),
                ButtonSegment(
                  value: TaskPeriod.afternoonEvening,
                  label: Text('Tarde/Noite'),
                ),
                ButtonSegment(
                  value: TaskPeriod.anytime,
                  label: Text('Qualquer'),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (selection) =>
                  setState(() => _period = selection.first),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tarefa bônus'),
              subtitle: const Text(
                'Opcional, não prejudica o progresso quando não concluída',
              ),
              value: _isBonus,
              onChanged: (value) => setState(() {
                _isBonus = value;
                if (value) _isRequired = false;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obrigatória'),
              value: _isRequired,
              onChanged: _isBonus
                  ? null
                  : (value) => setState(() => _isRequired = value),
            ),
            const SizedBox(height: 16),
            const Text('Aprovação'),
            const SizedBox(height: 8),
            SegmentedButton<ApprovalMode>(
              segments: const [
                ButtonSegment(
                  value: ApprovalMode.automatic,
                  label: Text('Automática'),
                ),
                ButtonSegment(
                  value: ApprovalMode.manual,
                  label: Text('Manual'),
                ),
              ],
              selected: {_approvalMode},
              onSelectionChanged: (selection) =>
                  setState(() => _approvalMode = selection.first),
            ),
            const SizedBox(height: 16),
            const Text('Após o prazo'),
            const SizedBox(height: 8),
            SegmentedButton<LatePolicy>(
              segments: const [
                ButtonSegment(
                  value: LatePolicy.allowLate,
                  label: Text('Permitir atraso'),
                ),
                ButtonSegment(
                  value: LatePolicy.expireNoReward,
                  label: Text('Expirar sem recompensa'),
                ),
              ],
              selected: {_latePolicy},
              onSelectionChanged: (selection) =>
                  setState(() => _latePolicy = selection.first),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Agenda'),
            const SizedBox(height: 8),
            SegmentedButton<ScheduleType>(
              segments: const [
                ButtonSegment(
                  value: ScheduleType.recurring,
                  label: Text('Recorrente'),
                ),
                ButtonSegment(
                  value: ScheduleType.once,
                  label: Text('Data única'),
                ),
              ],
              selected: {_scheduleType},
              onSelectionChanged: (selection) =>
                  setState(() => _scheduleType = selection.first),
            ),
            const SizedBox(height: 12),
            if (_scheduleType == ScheduleType.recurring)
              _buildRecurringFields()
            else
              _buildOnceFields(),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _startTime == null
                    ? 'Horário inicial (opcional)'
                    : 'Início: ${_startTime!.format(context)}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime:
                      _startTime ?? const TimeOfDay(hour: 8, minute: 0),
                );
                if (picked != null) setState(() => _startTime = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dueTime == null
                    ? 'Prazo final (opcional)'
                    : 'Prazo: ${_dueTime!.format(context)}',
              ),
              trailing: const Icon(Icons.alarm),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _dueTime ?? const TimeOfDay(hour: 19, minute: 0),
                );
                if (picked != null) setState(() => _dueTime = picked);
              },
            ),
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

  String? _nonNegativeIntValidator(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0) return 'Informe um número válido';
    return null;
  }

  Widget _buildRecurringFields() {
    return Wrap(
      spacing: 8,
      children: List.generate(7, (index) {
        final selected = _weekdays.contains(index);
        return FilterChip(
          label: Text(_weekdayLabels[index]),
          selected: selected,
          onSelected: (value) => setState(() {
            if (value) {
              _weekdays.add(index);
            } else {
              _weekdays.remove(index);
            }
          }),
        );
      }),
    );
  }

  Widget _buildOnceFields() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        _oneTimeDate == null
            ? 'Escolha a data'
            : '${_oneTimeDate!.day}/${_oneTimeDate!.month}/${_oneTimeDate!.year}',
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: DateTime(now.year + 1),
          initialDate: _oneTimeDate ?? now,
          helpText: 'Data da tarefa',
        );
        if (picked != null) setState(() => _oneTimeDate = picked);
      },
    );
  }
}
