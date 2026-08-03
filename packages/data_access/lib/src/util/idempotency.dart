import 'dart:math';

/// Gera uma chave de idempotência aleatória para ações críticas (docs/04
/// seção 8: toda aprovação/conclusão precisa de uma, para que duplo-tap ou
/// retry nunca creditem duas vezes).
///
/// Formato UUID v4, gerado localmente sem depender de um pacote externo —
/// só usado como identificador opaco único, nunca decodificado.
String newIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
