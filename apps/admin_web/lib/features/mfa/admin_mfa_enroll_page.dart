import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Enrolamento obrigatório do segundo fator (TOTP): nenhum administrador
/// chega a um módulo do painel sem isso (docs/12 seções 2 e 10). Mostra a
/// chave secreta para digitar manualmente num app autenticador — sem QR
/// code nesta fatia para não trazer uma dependência de renderização de SVG
/// só para a fundação do painel (uso interno, poucos operadores).
class AdminMfaEnrollPage extends ConsumerStatefulWidget {
  const AdminMfaEnrollPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<AdminMfaEnrollPage> createState() => _AdminMfaEnrollPageState();
}

class _AdminMfaEnrollPageState extends ConsumerState<AdminMfaEnrollPage> {
  final _codeController = TextEditingController();
  late final Future<TotpEnrollment> _enrollment;
  bool _verifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _enrollment = ref
        .read(adminMfaRepositoryProvider)
        .enrollTotp(friendlyName: 'painel-admin');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify(String factorId) async {
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
          .verifyFactor(factorId: factorId, code: _codeController.text.trim());
      await ref
          .read(adminAuditLogRepositoryProvider)
          .record(
            action: 'admin.mfa_enrolled',
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
      appBar: AppBar(title: const Text('Ativar autenticação em duas etapas')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<TotpEnrollment>(
              future: _enrollment,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const AsyncErrorBanner(
                    message:
                        'Não foi possível iniciar o cadastro do segundo '
                        'fator. Tente novamente em instantes.',
                  );
                }
                final enrollment = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_errorMessage != null)
                        AsyncErrorBanner(message: _errorMessage!),
                      const Text(
                        'MFA é obrigatório para todo administrador do '
                        "Kid's Task. Adicione esta conta a um aplicativo "
                        'autenticador (Google Authenticator, 1Password, '
                        'Authy etc.) digitando a chave abaixo e confirme '
                        'com o código de 6 dígitos gerado.',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Chave secreta',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        enrollment.secret,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Código de 6 dígitos',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _verifying
                            ? null
                            : () => _verify(enrollment.factorId),
                        child: _verifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirmar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
