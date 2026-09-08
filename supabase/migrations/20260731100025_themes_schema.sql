-- Marco 5 — Temas e Experiência por Idade (parte 1/3)
-- Catálogo de temas publicado no backend (substitui a lista estática que
-- só existia em `packages/design_system`) e solicitações de tema Premium.
-- Ver docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md, docs/09_MODELO_DE_DADOS.md
-- seção 6, docs/14 seção 6.

create table public.themes (
  id uuid primary key default extensions.gen_random_uuid(),
  slug text not null unique,
  name text not null,
  plan_tier text not null check (plan_tier in ('free', 'premium')),
  -- Guarda a referência ao asset do tema (ex.: {"background_asset_key":
  -- "block_world"}), resolvida no cliente contra o catálogo já processado
  -- em packages/design_system — não existe pipeline de CDN/densidade
  -- própria ainda, então theme_assets (docs/09) fica fora deste marco.
  manifest_json jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  status text not null default 'draft' check (status in ('draft', 'published', 'retired')),
  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.themes is
  'Catálogo pretendido: docs/06 seção 3. Só entra como published aqui o '
  'tema que já tem build real em packages/design_system (contrato de tema, '
  'docs/06 seção 5) — os demais ficam draft até ter arte própria, sem '
  'mudar a navegação quando publicados (docs/06 seção 3).';

alter table public.themes enable row level security;

create policy "themes_select_authenticated" on public.themes
  for select
  to authenticated
  using (status = 'published');

-- Sem policy de insert/update/delete: publicar/retirar tema é
-- responsabilidade do painel de conteúdo (Marco 7), não do app móvel.

insert into public.themes (slug, name, plan_tier, manifest_json, status, published_at) values
  ('kids_default', 'Tema Infantil Padrão', 'free', '{"background_asset_key": null}'::jsonb, 'published', timezone('utc', now())),
  ('block_world', 'Mundo dos Blocos', 'free', '{"background_asset_key": "block_world"}'::jsonb, 'published', timezone('utc', now())),
  ('space_adventure', 'Aventura Espacial', 'premium', '{"background_asset_key": "space_adventure"}'::jsonb, 'published', timezone('utc', now())),
  ('castles_quest', 'Princesas e Castelos', 'premium', '{"background_asset_key": "castles_quest"}'::jsonb, 'published', timezone('utc', now())),
  ('enchanted_world', 'Mundo Encantado', 'premium', '{}'::jsonb, 'draft', null),
  ('web_hero', 'Herói Aracnídeo', 'premium', '{}'::jsonb, 'draft', null),
  ('dino_adventure', 'Dinossauros', 'premium', '{}'::jsonb, 'draft', null),
  ('racing_world', 'Carros e Corridas', 'premium', '{}'::jsonb, 'draft', null),
  ('forest_friends', 'Animais da Floresta', 'premium', '{}'::jsonb, 'draft', null);

-- child_profiles.theme_slug existe desde o Marco 1 sem FK ("chega no
-- Marco 5" — ver comentário original na migration 20260731100003, já
-- commitada e não editada). Amarra agora que o catálogo existe de verdade.
alter table public.child_profiles
  add constraint child_profiles_theme_slug_fkey
  foreign key (theme_slug) references public.themes (slug);

create table public.theme_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  category text not null,
  colors text,
  description text,
  target_age_range text,
  consent boolean not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed')),
  created_by uuid not null default auth.uid() references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.theme_requests is
  'Formulário de docs/06 seção 10. Nunca coleta foto da criança. Revisão/'
  'transformação em tema real é trabalho do painel de conteúdo (Marco 7) '
  '— aqui só o registro da ideia.';

alter table public.theme_requests enable row level security;

create policy "theme_requests_select_guardian" on public.theme_requests
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = theme_requests.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- Sem policy de insert: escrita só via submit_theme_request (valida
-- consentimento e categoria antes de gravar).
