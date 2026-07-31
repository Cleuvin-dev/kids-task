/// DTOs, clientes e repositórios de acesso a dados do Kid's Task.
///
/// Depende de Flutter (via `supabase_flutter`) para aproveitar persistência
/// segura de sessão e deep links nativos das duas apps do monorepo. No
/// Marco 0 contém apenas a configuração de ambiente e o cliente Supabase;
/// repositórios por feature são adicionados a partir do Marco 1.
library;

export 'src/client/kids_task_supabase.dart';
export 'src/config/supabase_env.dart';
