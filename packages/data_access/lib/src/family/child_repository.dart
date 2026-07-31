import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

class DevicePairingCode {
  const DevicePairingCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Operações do responsável sobre perfis infantis e seus aparelhos
/// (docs/03, docs/14 seção 2).
class ChildRepository {
  ChildRepository(this._client);

  final SupabaseClient _client;

  Future<String> createChild({
    required String familyId,
    required String firstName,
    required DateTime birthDate,
    String? nickname,
    String avatarId = 'default',
  }) async {
    try {
      final rows = await _client.rpc(
        'create_child',
        params: {
          'p_family_id': familyId,
          'p_first_name': firstName,
          'p_birth_date': _dateOnly(birthDate),
          'p_nickname': nickname,
          'p_avatar_id': avatarId,
        },
      );
      final row = (rows as List).single as Map<String, dynamic>;
      return row['child_id'] as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// `pin: null` desativa o PIN da criança.
  Future<void> setChildPin({
    required String childId,
    required String? pin,
  }) async {
    try {
      await _client.rpc(
        'set_child_pin',
        params: {'p_child_id': childId, 'p_pin': pin},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listChildren(String familyId) async {
    try {
      final rows = await _client
          .from('child_profiles')
          .select()
          .eq('family_id', familyId)
          .eq('status', 'active')
          .order('created_at');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listDeviceBindings(String childId) async {
    try {
      final rows = await _client
          .from('child_device_bindings')
          .select()
          .eq('child_id', childId)
          .order('authorized_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> revokeDevice(String bindingId) async {
    try {
      await _client.rpc(
        'revoke_child_device',
        params: {'p_binding_id': bindingId},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<DevicePairingCode> createDevicePairingCode(String childId) async {
    try {
      final rows = await _client.rpc(
        'create_device_pairing_code',
        params: {'p_child_id': childId},
      );
      final row = (rows as List).single as Map<String, dynamic>;
      return DevicePairingCode(
        code: row['pairing_code'] as String,
        expiresAt: DateTime.parse(row['expires_at'] as String),
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
