/// Entidades, contratos e casos de uso compartilhados do Kid's Task.
///
/// Este pacote não depende de Flutter nem de infraestrutura (Supabase, HTTP).
/// Cresce a cada marco do roadmap (`docs/16_BACKLOG_E_ROADMAP.md`); no Marco 0
/// contém apenas os fundamentos de autorização e tratamento de erro
/// reutilizados por todos os recursos futuros.
library;

export 'src/auth/admin_role.dart';
export 'src/auth/user_role.dart';
export 'src/common/result.dart';
export 'src/errors/domain_error_code.dart';
export 'src/errors/domain_failure.dart';
export 'src/rewards/redemption_status.dart';
export 'src/tasks/approval_mode.dart';
export 'src/tasks/late_policy.dart';
export 'src/tasks/occurrence_status.dart';
export 'src/tasks/schedule_type.dart';
export 'src/tasks/task_period.dart';
