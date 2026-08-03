/// DTOs, clientes e repositórios de acesso a dados do Kid's Task.
///
/// Depende de Flutter (via `supabase_flutter`) para aproveitar persistência
/// segura de sessão e deep links nativos das duas apps do monorepo.
library;

export 'src/auth/guardian_auth_repository.dart';
export 'src/auth/session_role_resolver.dart';
export 'src/child_access/child_access_repository.dart';
export 'src/client/kids_task_supabase.dart';
export 'src/config/supabase_env.dart';
export 'src/errors/supabase_error_mapper.dart';
export 'src/family/child_repository.dart';
export 'src/family/family_repository.dart';
export 'src/providers.dart';
export 'src/rewards/redemption_repository.dart';
export 'src/rewards/reward_repository.dart';
export 'src/tasks/occurrence_repository.dart';
export 'src/tasks/progress_repository.dart';
export 'src/tasks/task_repository.dart';
export 'src/tasks/task_template_repository.dart';
export 'src/tasks/wallet_repository.dart';
export 'src/util/idempotency.dart';
