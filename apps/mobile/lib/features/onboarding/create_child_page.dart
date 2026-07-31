import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

class CreateChildPage extends ConsumerStatefulWidget {
  const CreateChildPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<CreateChildPage> createState() => _CreateChildPageState();
}

class _CreateChildPageState extends ConsumerState<CreateChildPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  DateTime? _birthDate;
  String _avatarId = childAvatarCatalog.first.id;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      initialDate: DateTime(now.year - 6),
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _birthDate == null) {
      setState(
        () => _errorMessage = _birthDate == null
            ? 'Informe a data de nascimento'
            : null,
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(childRepositoryProvider)
          .createChild(
            familyId: widget.familyId,
            firstName: _firstNameController.text.trim(),
            birthDate: _birthDate!,
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            avatarId: _avatarId,
          );
      ref.invalidate(resolvedSessionProvider);
      if (mounted) context.go('/');
    } on DomainFailure catch (e) {
      setState(
        () => _errorMessage =
            e.message ?? 'Não foi possível cadastrar a criança.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar criança')),
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
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Informe o nome'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Apelido (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _birthDate == null
                      ? 'Data de nascimento'
                      : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickBirthDate,
              ),
              const SizedBox(height: 12),
              const Text('Avatar'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: childAvatarCatalog.map((avatar) {
                  final selected = avatar.id == _avatarId;
                  return GestureDetector(
                    onTap: () => setState(() => _avatarId = avatar.id),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: avatar.color,
                      child: Icon(
                        avatar.icon,
                        color: Colors.white,
                        size: selected ? 28 : 22,
                      ),
                    ),
                  );
                }).toList(),
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
                    : const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
