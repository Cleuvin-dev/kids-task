import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

class CreatedFamily {
  const CreatedFamily({required this.familyId, required this.familyCode});

  final String familyId;

  /// Exibido uma única vez ao responsável — o backend nunca guarda o valor
  /// em claro (docs/03 seção 5).
  final String familyCode;
}

class GuardianInvite {
  const GuardianInvite({
    required this.inviteId,
    required this.expiresAt,
    required this.inviteLink,
    required this.emailDelivery,
  });

  final String inviteId;
  final DateTime expiresAt;
  final String inviteLink;

  /// "sent" | "not_configured" | "failed". Ver
  /// `supabase/functions/send-guardian-invite` para o bloqueio de provedor
  /// de e-mail ainda não configurado.
  final String emailDelivery;
}

/// Operações de família e responsáveis (docs/03, docs/14 seção 2).
class FamilyRepository {
  FamilyRepository(this._client);

  final SupabaseClient _client;

  Future<CreatedFamily> createFamily({
    required String name,
    String timezone = 'America/Sao_Paulo',
    String guardianTheme = 'blue',
  }) async {
    try {
      final rows = await _client.rpc(
        'create_family',
        params: {
          'p_name': name,
          'p_timezone': timezone,
          'p_guardian_theme': guardianTheme,
        },
      );
      final row = (rows as List).single as Map<String, dynamic>;
      return CreatedFamily(
        familyId: row['family_id'] as String,
        familyCode: row['family_code'] as String,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<String> rotateFamilyCode(String familyId) async {
    try {
      final rows = await _client.rpc(
        'rotate_family_code',
        params: {'p_family_id': familyId},
      );
      final row = (rows as List).single as Map<String, dynamic>;
      return row['family_code'] as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<GuardianInvite> inviteGuardian({
    required String familyId,
    required String email,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'send-guardian-invite',
        body: {'family_id': familyId, 'email': email},
      );
      final data = response.data as Map<String, dynamic>;
      return GuardianInvite(
        inviteId: data['invite_id'] as String,
        expiresAt: DateTime.parse(data['expires_at'] as String),
        inviteLink: data['invite_link'] as String,
        emailDelivery: data['email_delivery'] as String,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> cancelGuardianInvite(String inviteId) async {
    try {
      await _client.rpc(
        'cancel_guardian_invite',
        params: {'p_invite_id': inviteId},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Retorna o id da família aceita (útil quando o convidado ainda não tinha
  /// nenhuma família vinculada localmente).
  Future<String> acceptGuardianInvite(String token) async {
    try {
      final rows = await _client.rpc(
        'accept_guardian_invite',
        params: {'p_token': token},
      );
      final row = (rows as List).single as Map<String, dynamic>;
      return row['family_id'] as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> removeGuardian({
    required String familyId,
    required String profileId,
  }) async {
    try {
      await _client.rpc(
        'remove_guardian',
        params: {'p_family_id': familyId, 'p_profile_id': profileId},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>?> fetchFamily(String familyId) async {
    try {
      return await _client
          .from('families')
          .select()
          .eq('id', familyId)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// `theme` é `'blue'` ou `'pink'` (docs/06 seção 1). Escrita simples via
  /// RLS — sem regra de negócio além de autorização (a policy
  /// `families_update_guardian` já cobre isso desde o Marco 1).
  Future<void> updateGuardianTheme({
    required String familyId,
    required String theme,
  }) async {
    try {
      await _client
          .from('families')
          .update({'guardian_theme': theme})
          .eq('id', familyId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listFamilyMembers(String familyId) async {
    try {
      final rows = await _client
          .from('family_members')
          .select('profile_id, role, status, joined_at, profiles(display_name)')
          .eq('family_id', familyId)
          .eq('status', 'active');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> recordConsent({
    required String familyId,
    required String document,
    required String documentVersion,
    required String purpose,
  }) async {
    try {
      await _client.from('consent_records').insert({
        'family_id': familyId,
        'guardian_profile_id': _client.auth.currentUser!.id,
        'document': document,
        'document_version': documentVersion,
        'purpose': purpose,
      });
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
