import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

enum _ChildAccessStep { code, selectChild, credential }

/// Acesso da criança: código da família → seleção de perfil → PIN ou
/// pareamento (docs/03 seção 6; docs/07 seção 2).
///
/// Erros são sempre genéricos, sem indicar qual dado estava incorreto
/// (proteção contra enumeração).
class ChildAccessPage extends ConsumerStatefulWidget {
  const ChildAccessPage({super.key});

  @override
  ConsumerState<ChildAccessPage> createState() => _ChildAccessPageState();
}

class _ChildAccessPageState extends ConsumerState<ChildAccessPage> {
  _ChildAccessStep _step = _ChildAccessStep.code;
  final _codeController = TextEditingController();
  final _credentialController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  List<ChildSelectionOption> _children = const [];
  ChildSelectionOption? _selectedChild;

  @override
  void dispose() {
    _codeController.dispose();
    _credentialController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(childAccessRepositoryProvider);
      await repo.ensureDeviceSession();
      final children = await repo.resolveFamilyChildren(
        _codeController.text.trim(),
      );
      setState(() {
        _children = children;
        _step = _ChildAccessStep.selectChild;
      });
    } catch (_) {
      setState(
        () => _errorMessage =
            'Código inválido. Confira com um responsável e tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCredential() async {
    final child = _selectedChild;
    if (child == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(childAccessRepositoryProvider);
      await repo.authorizeDevice(
        familyCode: _codeController.text.trim(),
        childId: child.childId,
        deviceName: 'Aparelho de ${child.displayName}',
        pin: child.pinEnabled ? _credentialController.text.trim() : null,
        pairingCode: child.pinEnabled
            ? null
            : _credentialController.text.trim(),
      );
      ref.invalidate(resolvedSessionProvider);
      if (mounted) context.go('/');
    } catch (_) {
      setState(
        () => _errorMessage =
            'Não foi possível entrar. Confira e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso da criança'),
        leading: BackButton(
          onPressed: () {
            if (_step == _ChildAccessStep.code) {
              context.go('/access');
            } else {
              setState(() {
                _errorMessage = null;
                _step = _ChildAccessStep.values[_step.index - 1];
              });
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: switch (_step) {
          _ChildAccessStep.code => _buildCodeStep(),
          _ChildAccessStep.selectChild => _buildSelectChildStep(),
          _ChildAccessStep.credential => _buildCredentialStep(),
        },
      ),
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) AsyncErrorBanner(message: _errorMessage!),
        const Text('Digite o código da sua família'),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'KT7F-9Q2M'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitCode,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _buildSelectChildStep() {
    if (_children.isEmpty) {
      return const Center(
        child: Text('Nenhum perfil encontrado para esta família.'),
      );
    }
    return ListView(
      children: _children.map((child) {
        final avatar = childAvatarById(child.avatarId);
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: avatar.color,
              child: Icon(avatar.icon, color: Colors.white),
            ),
            title: Text(child.displayName),
            onTap: () => setState(() {
              _selectedChild = child;
              _credentialController.clear();
              _step = _ChildAccessStep.credential;
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCredentialStep() {
    final child = _selectedChild!;
    final avatar = childAvatarById(child.avatarId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) AsyncErrorBanner(message: _errorMessage!),
        Row(
          children: [
            CircleAvatar(
              backgroundColor: avatar.color,
              child: Icon(avatar.icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              child.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          child.pinEnabled
              ? 'Digite seu PIN'
              : 'Peça para um responsável gerar um código de pareamento e digite-o abaixo',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _credentialController,
          obscureText: child.pinEnabled,
          keyboardType: child.pinEnabled
              ? TextInputType.number
              : TextInputType.text,
          textCapitalization: child.pinEnabled
              ? TextCapitalization.none
              : TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: child.pinEnabled ? '••••' : 'Código de pareamento',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submitCredential,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Entrar'),
        ),
      ],
    );
  }
}
