import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

const _brazilianTimezones = [
  'America/Sao_Paulo',
  'America/Manaus',
  'America/Rio_Branco',
  'America/Fortaleza',
];

class CreateFamilyPage extends ConsumerStatefulWidget {
  const CreateFamilyPage({super.key, this.documentVersion});

  final String? documentVersion;

  @override
  ConsumerState<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends ConsumerState<CreateFamilyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _timezone = _brazilianTimezones.first;
  GuardianThemeOption _theme = GuardianThemeOption.blue;
  bool _loading = false;
  String? _errorMessage;
  CreatedFamily? _createdFamily;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final created = await ref
          .read(familyRepositoryProvider)
          .createFamily(
            name: _nameController.text.trim(),
            timezone: _timezone,
            guardianTheme: _theme.name,
          );
      await ref
          .read(familyRepositoryProvider)
          .recordConsent(
            familyId: created.familyId,
            document: 'consentimento_dados_infantis',
            documentVersion: widget.documentVersion ?? 'desconhecida',
            purpose: 'cadastro_familia_criacao',
          );
      setState(() => _createdFamily = created);
    } on DomainFailure catch (e) {
      setState(
        () => _errorMessage = e.message ?? 'Não foi possível criar a família.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _createdFamily;
    if (created != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Família criada!')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Este é o código da sua família. Guarde-o: as crianças usam este código para entrar.',
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        created.familyCode,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: created.familyCode),
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar código'),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go(
                  '/onboarding/child',
                  extra: {'familyId': created.familyId},
                ),
                child: const Text('Cadastrar a primeira criança'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar família')),
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
                decoration: const InputDecoration(labelText: 'Nome da família'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe um nome'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _timezone,
                decoration: const InputDecoration(labelText: 'Fuso horário'),
                items: _brazilianTimezones
                    .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _timezone = value ?? _timezone),
              ),
              const SizedBox(height: 12),
              const Text('Cor da área do responsável (sem relação com gênero)'),
              RadioGroup<GuardianThemeOption>(
                groupValue: _theme,
                onChanged: (value) => setState(() => _theme = value ?? _theme),
                child: const Column(
                  children: [
                    RadioListTile<GuardianThemeOption>(
                      value: GuardianThemeOption.blue,
                      title: Text('Azul padrão'),
                    ),
                    RadioListTile<GuardianThemeOption>(
                      value: GuardianThemeOption.pink,
                      title: Text('Rosa'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar família'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
