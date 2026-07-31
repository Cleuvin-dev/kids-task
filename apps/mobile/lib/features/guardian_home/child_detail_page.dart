import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      setState(() => _devices = devices);
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
