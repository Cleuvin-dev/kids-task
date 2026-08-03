import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

const _ageRanges = ['2-7', '8-10', '11-13+'];

/// Formulário de ideia de tema Premium (docs/06 seção 10). Nunca coleta
/// foto da criança.
class ThemeRequestPage extends ConsumerStatefulWidget {
  const ThemeRequestPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<ThemeRequestPage> createState() => _ThemeRequestPageState();
}

class _ThemeRequestPageState extends ConsumerState<ThemeRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _colorsController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _ageRange = _ageRanges.first;
  bool _consent = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _categoryController.dispose();
    _colorsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(
        () => _errorMessage = 'É preciso concordar com a análise da ideia.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(themeRepositoryProvider)
          .submitThemeRequest(
            familyId: widget.familyId,
            category: _categoryController.text.trim(),
            colors: _colorsController.text.trim().isEmpty
                ? null
                : _colorsController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            targetAgeRange: _ageRange,
            consent: _consent,
          );
      if (mounted) context.pop();
    } catch (_) {
      setState(() => _errorMessage = 'Não foi possível enviar a ideia agora.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar um tema')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null)
              AsyncErrorBanner(message: _errorMessage!),
            const Text(
              'Conte a ideia do tema que sua família gostaria de ver. Não '
              'envie foto da criança.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Categoria (ex.: espaço, fantasia, esportes)',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe a categoria'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _colorsController,
              decoration: const InputDecoration(labelText: 'Cores (opcional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição livre (opcional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ageRange,
              decoration: const InputDecoration(labelText: 'Faixa etária'),
              items: _ageRanges
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _ageRange = value ?? _ageRange),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (value) => setState(() => _consent = value ?? false),
              title: const Text('Aceito que a equipe analise esta ideia'),
              controlAffinity: ListTileControlAffinity.leading,
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
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
