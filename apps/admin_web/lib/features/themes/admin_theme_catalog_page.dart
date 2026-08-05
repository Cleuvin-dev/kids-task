import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

const _statusLabels = {
  'draft': 'Rascunho',
  'published': 'Publicado',
  'retired': 'Retirado',
};

const _planTierLabels = {'free': 'Gratuito', 'premium': 'Premium'};

/// Módulo "Temas e conteúdo" (docs/12 seção 6): catálogo de temas (criar
/// rascunho, apontar a chave de asset já processada em
/// `packages/design_system`, publicar, retirar) e a fila de solicitações
/// Premium de tema (`theme_requests`, Marco 5).
///
/// "Upload de assets" não é upload de arquivo aqui — o catálogo de temas do
/// app é código Dart compilado, não carregado de um Storage em runtime; o
/// painel administra o metadado do catálogo, a arte em si continua sendo
/// um processo manual de desenvolvimento (ver comentário na migration).
class AdminThemeCatalogPage extends ConsumerStatefulWidget {
  const AdminThemeCatalogPage({super.key});

  @override
  ConsumerState<AdminThemeCatalogPage> createState() =>
      _AdminThemeCatalogPageState();
}

class _AdminThemeCatalogPageState extends ConsumerState<AdminThemeCatalogPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _themes = const [];
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminThemeRepositoryProvider);
      final themes = await repo.listThemes();
      final requests = await repo.listThemeRequests();
      setState(() {
        _themes = themes;
        _requests = requests;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar o catálogo agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createDraft() async {
    final input = await showDialog<_DraftInput>(
      context: context,
      builder: (context) => const _CreateDraftDialog(),
    );
    if (input == null) return;
    try {
      await ref
          .read(adminThemeRepositoryProvider)
          .createThemeDraft(
            slug: input.slug,
            name: input.name,
            planTier: input.planTier,
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível criar o rascunho agora.');
    }
  }

  Future<void> _editManifest(Map<String, dynamic> theme) async {
    final assetKey = await showDialog<String>(
      context: context,
      builder: (context) => _EditManifestDialog(
        initialAssetKey:
            (theme['manifest_json']
                    as Map<String, dynamic>?)?['background_asset_key']
                as String?,
      ),
    );
    if (assetKey == null) return;
    try {
      await ref
          .read(adminThemeRepositoryProvider)
          .updateThemeManifest(
            themeId: theme['theme_id'] as String,
            manifest: {
              'background_asset_key': assetKey.trim().isEmpty
                  ? null
                  : assetKey.trim(),
            },
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível salvar o manifest agora.');
    }
  }

  Future<void> _publish(Map<String, dynamic> theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _PublishDialog(),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(adminThemeRepositoryProvider)
          .publishTheme(
            themeId: theme['theme_id'] as String,
            ipReviewConfirmed: true,
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível publicar o tema agora.');
    }
  }

  Future<void> _retire(Map<String, dynamic> theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar tema'),
        content: Text(
          'Retirar "${theme['name']}" tira o tema do catálogo para novas '
          'escolhas. Famílias que já usam o tema não são afetadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(adminThemeRepositoryProvider)
          .retireTheme(theme['theme_id'] as String);
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível retirar o tema agora.');
    }
  }

  Future<void> _reviewRequest(String requestId) async {
    try {
      await ref
          .read(adminThemeRepositoryProvider)
          .reviewThemeRequest(requestId);
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível marcar como revisado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temas e conteúdo'),
        actions: [
          IconButton(
            tooltip: 'Criar rascunho',
            icon: const Icon(Icons.add),
            onPressed: _createDraft,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  Text(
                    'Catálogo de temas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._themes.map(_buildThemeTile),
                  const SizedBox(height: 24),
                  Text(
                    'Solicitações Premium de tema',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_requests.isEmpty) const Text('Nenhuma solicitação.'),
                  ..._requests.map(_buildRequestTile),
                ],
              ),
            ),
    );
  }

  Widget _buildThemeTile(Map<String, dynamic> theme) {
    final status = theme['status'] as String;
    return Card(
      child: ListTile(
        title: Text('${theme['name']} (${theme['slug']})'),
        subtitle: Text(
          '${_statusLabels[status] ?? status} · '
          '${_planTierLabels[theme['plan_tier']] ?? theme['plan_tier']} · '
          'v${theme['version']}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            if (status != 'retired')
              TextButton(
                onPressed: () => _editManifest(theme),
                child: const Text('Editar asset'),
              ),
            if (status != 'published')
              TextButton(
                onPressed: () => _publish(theme),
                child: const Text('Publicar'),
              ),
            if (status == 'published')
              TextButton(
                onPressed: () => _retire(theme),
                child: const Text('Retirar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    final isPending = request['status'] == 'pending';
    return Card(
      child: ListTile(
        title: Text('${request['category']} · ${request['family_name']}'),
        subtitle: Text(
          '${request['requested_by_email']} · '
          '${request['target_age_range'] ?? '—'} · '
          '${_dateFormat.format(DateTime.parse(request['created_at'] as String).toLocal())}'
          '${request['description'] != null ? '\n${request['description']}' : ''}',
        ),
        isThreeLine: request['description'] != null,
        trailing: isPending
            ? TextButton(
                onPressed: () =>
                    _reviewRequest(request['request_id'] as String),
                child: const Text('Marcar como revisado'),
              )
            : const Text('Revisado'),
      ),
    );
  }
}

class _DraftInput {
  const _DraftInput({
    required this.slug,
    required this.name,
    required this.planTier,
  });

  final String slug;
  final String name;
  final String planTier;
}

class _CreateDraftDialog extends StatefulWidget {
  const _CreateDraftDialog();

  @override
  State<_CreateDraftDialog> createState() => _CreateDraftDialogState();
}

class _CreateDraftDialogState extends State<_CreateDraftDialog> {
  final _slugController = TextEditingController();
  final _nameController = TextEditingController();
  String _planTier = 'free';

  @override
  void dispose() {
    _slugController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Criar rascunho de tema'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _slugController,
            decoration: const InputDecoration(
              labelText: 'Slug (ex.: forest_friends)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _planTier,
            decoration: const InputDecoration(labelText: 'Plano'),
            items: const [
              DropdownMenuItem(value: 'free', child: Text('Gratuito')),
              DropdownMenuItem(value: 'premium', child: Text('Premium')),
            ],
            onChanged: (value) => setState(() => _planTier = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              _slugController.text.trim().isEmpty ||
                  _nameController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _DraftInput(
                    slug: _slugController.text.trim(),
                    name: _nameController.text.trim(),
                    planTier: _planTier,
                  ),
                ),
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

class _EditManifestDialog extends StatefulWidget {
  const _EditManifestDialog({required this.initialAssetKey});

  final String? initialAssetKey;

  @override
  State<_EditManifestDialog> createState() => _EditManifestDialogState();
}

class _EditManifestDialogState extends State<_EditManifestDialog> {
  late final _controller = TextEditingController(
    text: widget.initialAssetKey ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar chave do asset'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chave já processada em packages/design_system (ex.: '
            'block_world). Publicar não avança sem uma chave preenchida.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'background_asset_key',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _PublishDialog extends StatefulWidget {
  const _PublishDialog();

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Publicar tema'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirme que a arte já foi revisada quanto a licença/'
            'proveniência, contraste e acessibilidade, propriedade '
            'intelectual e tamanho máximo (docs/12 seção 6).',
          ),
          CheckboxListTile(
            value: _confirmed,
            onChanged: (value) => setState(() => _confirmed = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Revisão concluída e aprovada'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Publicar'),
        ),
      ],
    );
  }
}
