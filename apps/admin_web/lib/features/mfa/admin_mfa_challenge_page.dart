import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Desafio de MFA para uma sessão que já tem um fator TOTP verificado, mas
/// ainda está em aal1 (login recente sem o segundo fator) — docs/12 seções
/// 2 e 10.
class AdminMfaChallengePage extends ConsumerStatefulWidget {
  const AdminMfaChallengePage({
    super.key,
    required this.profileId,
    required this.factorId,
  });

  final String profileId;
  final String factorId;

  @override
  ConsumerState<AdminMfaChallengePage> createState() =>
      _AdminMfaChallengePageState();
}

class _AdminMfaChallengePageState extends ConsumerState<AdminMfaChallengePage> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Informe o código de 6 dígitos.');
      return;
    }
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(adminMfaRepositoryProvider)
          .verifyFactor(
            factorId: widget.factorId,
            code: _codeController.text.trim(),
          );
      await ref
          .read(adminAuditLogRepositoryProvider)
          .record(
            action: 'admin.mfa_verified',
            resourceType: 'platform_admin',
            resourceId: widget.profileId,
          );
      ref.invalidate(adminResolvedSessionProvider);
      if (mounted) context.go('/');
    } on DomainFailure catch (e) {
      setState(() => _errorMessage = e.message ?? 'Código inválido.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificação em duas etapas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                  AsyncErrorBanner(message: _errorMessage!),
                const Text(
                  'Digite o código de 6 dígitos do seu aplicativo '
                  'autenticador para continuar.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
