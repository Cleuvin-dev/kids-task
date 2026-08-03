import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Central interna de notificações (docs/11 seção 1), usada tanto pelo
/// responsável quanto pela criança — a RLS de `notifications` já resolve
/// "de quem" é cada uma, então a tela é a mesma para os dois perfis.
class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifications = await ref
          .read(notificationRepositoryProvider)
          .listNotifications();
      setState(() => _notifications = notifications);
    } catch (_) {
      setState(
        () =>
            _errorMessage = 'Não foi possível carregar as notificações agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    if (notification['read_at'] == null) {
      try {
        await ref
            .read(notificationRepositoryProvider)
            .markAsRead(notification['id'] as String);
        await _load();
      } catch (_) {
        // Falha silenciosa: a notificação continua marcada como não lida.
      }
    }

    final deepLink = notification['deep_link'] as String?;
    if (deepLink != null && mounted) context.push(deepLink);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (_notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Nenhuma notificação ainda.')),
                    ),
                  ..._notifications.map(_buildCard),
                ],
              ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> notification) {
    final read = notification['read_at'] != null;
    return Card(
      color: read ? null : Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          read ? Icons.notifications_none : Icons.notifications_active,
        ),
        title: Text(notification['title'] as String),
        subtitle: Text(notification['body'] as String),
        onTap: () => _openNotification(notification),
      ),
    );
  }
}
