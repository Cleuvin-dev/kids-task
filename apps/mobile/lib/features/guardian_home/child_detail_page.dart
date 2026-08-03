import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// PIN e aparelhos autorizados de uma criança (docs/03 seções 6-8).
class ChildDetailPage extends ConsumerStatefulWidget {
  const ChildDetailPage({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildDetailPage> createState() => _ChildDetailPageState();
}

class _ChildDetailPageState extends ConsumerState<ChildDetailPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _devices = const [];
  int _coinBalance = 0;
  int _currentLevel = 1;
  int _currentStreak = 0;
  String _streakRule = 'at_least_one';
  int _streakPercentage = 80;
  int _levelBonusCoins = 5;
  int _birthdayBonusCoins = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final devices = await ref
          .read(childRepositoryProvider)
          .listDeviceBindings(widget.childId);
      final wallet = await ref
          .read(walletRepositoryProvider)
          .fetchWallet(widget.childId);
      final streak = await ref
          .read(progressRepositoryProvider)
          .fetchStreak(widget.childId);
      final profile = await ref
          .read(supabaseClientProvider)
          .from('child_profiles')
          .select(
            'streak_rule, streak_percentage, level_bonus_coins, birthday_bonus_coins',
          )
          .eq('id', widget.childId)
          .single();
      setState(() {
        _devices = devices;
        _coinBalance = wallet?['coin_balance'] as int? ?? 0;
        _currentLevel = wallet?['current_level'] as int? ?? 1;
        _currentStreak = streak?['current_streak'] as int? ?? 0;
        _streakRule = profile['streak_rule'] as String;
        _streakPercentage = profile['streak_percentage'] as int;
        _levelBonusCoins = profile['level_bonus_coins'] as int;
        _birthdayBonusCoins = profile['birthday_bonus_coins'] as int;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar os aparelhos agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPin() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Definir PIN (4 a 6 dígitos)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Remover PIN'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (pin == null) return;
    try {
      await ref
          .read(childRepositoryProvider)
          .setChildPin(childId: widget.childId, pin: pin.isEmpty ? null : pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pin.isEmpty ? 'PIN removido.' : 'PIN atualizado.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o PIN. Confira o formato (4 a 6 dígitos).',
            ),
          ),
        );
      }
    }
  }

  Future<void> _createPairingCode() async {
    try {
      final pairing = await ref
          .read(childRepositoryProvider)
          .createDevicePairingCode(widget.childId);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de pareamento'),
          content: Text(
            '${pairing.code}\n\nVálido por poucos minutos. Digite este código '
            'no aparelho da criança para autorizá-lo sem PIN.',
          ),
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
            content: Text('Não foi possível gerar o código agora.'),
          ),
        );
      }
    }
  }

  Future<void> _revoke(String bindingId) async {
    try {
      await ref.read(childRepositoryProvider).revokeDevice(bindingId);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível revogar agora.')),
        );
      }
    }
  }

  Future<void> _adjustCoins() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    var direction = 'credit';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajustar KidsCoins'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'credit', label: Text('Adicionar')),
                  ButtonSegment(value: 'debit', label: Text('Retirar')),
                ],
                selected: {direction},
                onSelectionChanged: (selection) =>
                    setDialogState(() => direction = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Motivo'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final amount = int.tryParse(amountController.text);
    if (amount == null || amount <= 0 || reasonController.text.trim().isEmpty) {
      _showError('Informe uma quantidade e um motivo válidos.');
      return;
    }

    try {
      await ref
          .read(walletRepositoryProvider)
          .adjustCoins(
            childId: widget.childId,
            amount: amount,
            direction: direction,
            reason: reasonController.text.trim(),
            idempotencyKey: newIdempotencyKey(),
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(
        e.code == DomainErrorCode.insufficientCoins
            ? 'Saldo insuficiente para essa retirada.'
            : 'Não foi possível ajustar o saldo agora.',
      );
    } catch (_) {
      _showError('Não foi possível ajustar o saldo agora.');
    }
  }

  Future<void> _editProgressSettings() async {
    final percentageController = TextEditingController(
      text: _streakPercentage.toString(),
    );
    final levelBonusController = TextEditingController(
      text: _levelBonusCoins.toString(),
    );
    final birthdayBonusController = TextEditingController(
      text: _birthdayBonusCoins.toString(),
    );
    var rule = _streakRule;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configurações de progresso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: rule,
                decoration: const InputDecoration(labelText: 'Regra de streak'),
                items: const [
                  DropdownMenuItem(
                    value: 'at_least_one',
                    child: Text('Ao menos uma tarefa'),
                  ),
                  DropdownMenuItem(
                    value: 'all_required',
                    child: Text('Todas as obrigatórias'),
                  ),
                  DropdownMenuItem(
                    value: 'percentage',
                    child: Text('Percentual mínimo'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => rule = value ?? rule),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: percentageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Percentual mínimo (%)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: levelBonusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bônus de KidsCoins por nível',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: birthdayBonusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bônus de aniversário (KidsCoins)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(progressRepositoryProvider)
          .updateProgressSettings(
            childId: widget.childId,
            streakRule: rule,
            streakPercentage:
                int.tryParse(percentageController.text) ?? _streakPercentage,
            levelBonusCoins:
                int.tryParse(levelBonusController.text) ?? _levelBonusCoins,
            birthdayBonusCoins:
                int.tryParse(birthdayBonusController.text) ??
                _birthdayBonusCoins,
          );
      await _load();
    } catch (_) {
      _showError('Não foi possível salvar as configurações agora.');
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
      appBar: AppBar(title: const Text('Perfil e aparelhos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  AsyncErrorBanner(message: _errorMessage!),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: Text('$_coinBalance KidsCoins'),
                    trailing: TextButton(
                      onPressed: _adjustCoins,
                      child: const Text('Ajustar'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Tema'),
                    subtitle: const Text('Personalização visual da criança'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/guardian/children/${widget.childId}/theme',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: Text(
                      'Nível $_currentLevel · $_currentStreak dias de streak',
                    ),
                    subtitle: const Text('Regra de streak e bônus'),
                    trailing: TextButton(
                      onPressed: _editProgressSettings,
                      child: const Text('Configurar'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('PIN de acesso'),
                        trailing: TextButton(
                          onPressed: _setPin,
                          child: const Text('Alterar'),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.qr_code_2_outlined),
                        title: const Text('Autorizar aparelho sem PIN'),
                        trailing: TextButton(
                          onPressed: _createPairingCode,
                          child: const Text('Gerar código'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      const ListTile(title: Text('Aparelhos autorizados')),
                      if (_devices.isEmpty)
                        const ListTile(
                          title: Text('Nenhum aparelho autorizado ainda.'),
                        ),
                      ..._devices.map((d) {
                        final revoked = d['revoked_at'] != null;
                        return ListTile(
                          leading: Icon(
                            revoked
                                ? Icons.phonelink_off
                                : Icons.phonelink_ring,
                          ),
                          title: Text(d['device_name'] as String),
                          subtitle: Text(
                            revoked
                                ? 'Revogado'
                                : 'Última atividade: ${d['last_seen_at']}',
                          ),
                          trailing: revoked
                              ? null
                              : TextButton(
                                  onPressed: () => _revoke(d['id'] as String),
                                  child: const Text('Revogar'),
                                ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
