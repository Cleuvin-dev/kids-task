import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Cadastro do responsável. Coleta apenas nome de exibição, e-mail e senha —
/// nenhum dado de gênero (CLAUDE.md).
class GuardianSignUpPage extends ConsumerStatefulWidget {
  const GuardianSignUpPage({super.key});

  @override
  ConsumerState<GuardianSignUpPage> createState() => _GuardianSignUpPageState();
}

class _GuardianSignUpPageState extends ConsumerState<GuardianSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  bool _awaitingEmailConfirmation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(guardianAuthRepositoryProvider);
      await repo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (repo.currentSession != null) {
        ref.invalidate(resolvedSessionProvider);
        if (mounted) context.go('/');
        return;
      }

      setState(() => _awaitingEmailConfirmation = true);
    } on DomainFailure catch (e) {
      setState(
        () => _errorMessage = e.message ?? 'Não foi possível criar a conta.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingEmailConfirmation) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirme seu e-mail')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'Enviamos um link de confirmação para o seu e-mail. Abra-o para '
                'continuar o cadastro da família.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                AsyncErrorBanner(message: _errorMessage!),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Seu nome'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe seu nome'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Informe um e-mail válido'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha'),
                validator: (value) => (value == null || value.length < 6)
                    ? 'Mínimo de 6 caracteres'
                    : null,
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
                    : const Text('Criar conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
