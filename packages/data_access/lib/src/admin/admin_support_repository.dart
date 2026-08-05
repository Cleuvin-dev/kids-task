import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Módulo "Suporte" do painel administrativo (docs/12 seção 9): tickets,
/// categoria e prioridade, timeline/resposta, encerramento e vínculo com
/// incidente.
///
/// Sem impersonação (docs/12 seção 9) — este repositório nunca dá acesso à
/// sessão de um responsável ou criança, só lê/escreve `support_tickets`/
/// `support_ticket_messages` via RLS comum (sem RPC dedicada, docs/14
/// seção 1: sem regra de negócio crítica além de autorização).
class AdminSupportRepository {
  AdminSupportRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listTickets() async {
    try {
      final rows = await _client
          .from('support_tickets')
          .select()
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Nome da família, para exibição — `null` quando o ticket não tem
  /// família vinculada (consulta geral).
  Future<String?> fetchFamilyName(String familyId) async {
    try {
      final row = await _client
          .from('families')
          .select('name')
          .eq('id', familyId)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<String> createTicket({
    String? familyId,
    required String subject,
    required String category,
    String priority = 'medium',
    String? incidentRef,
  }) async {
    try {
      final adminId = _client.auth.currentUser!.id;
      final row = await _client
          .from('support_tickets')
          .insert({
            'family_id': familyId,
            'subject': subject,
            'category': category,
            'priority': priority,
            'incident_ref': incidentRef,
            'created_by': adminId,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>?> fetchTicket(String ticketId) async {
    try {
      return await _client
          .from('support_tickets')
          .select()
          .eq('id', ticketId)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listMessages(String ticketId) async {
    try {
      final rows = await _client
          .from('support_ticket_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> addMessage({
    required String ticketId,
    required String body,
  }) async {
    try {
      final adminId = _client.auth.currentUser!.id;
      await _client.from('support_ticket_messages').insert({
        'ticket_id': ticketId,
        'author_admin_id': adminId,
        'body': body,
      });
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> updateStatus({
    required String ticketId,
    required String status,
  }) async {
    try {
      await _client
          .from('support_tickets')
          .update({'status': status})
          .eq('id', ticketId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
