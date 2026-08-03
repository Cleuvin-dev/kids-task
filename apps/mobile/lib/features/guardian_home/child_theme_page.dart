import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Seleção do tema individual da criança (docs/06 seção 2: "Crianças →
/// selecionar criança → Personalização → Tema → visualizar → aplicar").
class ChildThemePage extends ConsumerStatefulWidget {
  const ChildThemePage({
    super.key,
    required this.childId,
    required this.familyId,
  });

  final String childId;
  final String familyId;

  @override
  ConsumerState<ChildThemePage> createState() => _ChildThemePageState();
}

class _ChildThemePageState extends ConsumerState<ChildThemePage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _themes = const [];
  String _currentSlug = 'kids_default';
  String _planCode = 'free';
  final Set<String> _applying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final themes = await ref
          .read(themeRepositoryProvider)
          .listPublishedThemes();
      final child = await ref
          .read(supabaseClientProvider)
          .from('child_profiles')
          .select('theme_slug')
          .eq('id', widget.childId)
          .single();
      final family = await ref
          .read(supabaseClientProvider)
          .from('families')
          .select('plans(code)')
          .eq('id', widget.familyId)
          .single();
      setState(() {
        _themes = themes;
        _currentSlug = child['theme_slug'] as String? ?? 'kids_default';
        _planCode =
            (family['plans'] as Map<String, dynamic>?)?['code'] as String? ??
            'free';
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar os temas agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply(Map<String, dynamic> theme) async {
    final slug = theme['slug'] as String;
    setState(() => _applying.add(slug));
    try {
      await ref
          .read(themeRepositoryProvider)
          .applyChildTheme(childId: widget.childId, themeSlug: slug);
      ref.invalidate(childThemeSlugProvider(widget.childId));
      await _load();
    } on DomainFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == DomainErrorCode.themeNotEntitled
                  ? 'Esse tema é exclusivo do plano Premium.'
                  : 'Não foi possível aplicar o tema agora.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível aplicar o tema agora.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _applying.remove(slug));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema da criança'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Solicitar um tema',
            onPressed: () => context.push(
              '/guardian/theme-requests/new',
              extra: {'familyId': widget.familyId},
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  AsyncErrorBanner(message: _errorMessage!),
                ..._themes.map(_buildThemeCard),
              ],
            ),
    );
  }

  Widget _buildThemeCard(Map<String, dynamic> theme) {
    final slug = theme['slug'] as String;
    final isPremium = theme['plan_tier'] == 'premium';
    final locked = isPremium && _planCode != 'premium';
    final isCurrent = slug == _currentSlug;
    final isApplying = _applying.contains(slug);
    final preview = buildKidsThemeBySlug(slug).extension<KidsTaskTokens>()!;

    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: preview.colorPrimary),
        title: Text(theme['name'] as String),
        subtitle: Text(
          isPremium ? 'Premium' : 'Gratuito',
          style: TextStyle(color: locked ? Colors.grey : null),
        ),
        trailing: isCurrent
            ? const Chip(label: Text('Atual'))
            : locked
            ? const Icon(Icons.lock_outline)
            : FilledButton(
                onPressed: isApplying ? null : () => _apply(theme),
                child: isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aplicar'),
              ),
      ),
    );
  }
}
