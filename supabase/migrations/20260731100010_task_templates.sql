-- Marco 2 — Rotina e Tarefas (parte 3/8)
-- Catálogo global de tarefas prontas (somente leitura para famílias).
-- Ver docs/17_BANCO_INICIAL_DE_TAREFAS.md.

create table public.task_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null,
  icon_key text not null default 'default',
  category text not null,
  suggested_period text not null check (suggested_period in ('morning', 'afternoon_evening', 'anytime')),
  suggested_age_min smallint not null check (suggested_age_min >= 0),
  suggested_age_max smallint not null check (suggested_age_max >= suggested_age_min),
  guidance text,
  requires_supervision boolean not null default false,
  locale text not null default 'pt-BR',
  version integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.task_templates is
  'Templates globais, somente leitura para famílias (docs/17 seção 7). '
  'Criar uma tarefa a partir de um template copia os campos; editar a '
  'tarefa da família não muda o template.';

comment on column public.task_templates.requires_supervision is
  'Tarefas com cozinha, produtos de limpeza, animais ou áreas externas '
  'sinalizam supervisão (docs/17 seção 6). O texto de orientação exibido '
  'ao responsável não substitui cuidado ou diálogo.';

alter table public.task_templates enable row level security;

create policy "task_templates_select_authenticated" on public.task_templates
  for select
  to authenticated
  using (active);

-- Sem policy de insert/update/delete: publicação de templates é
-- responsabilidade do painel de conteúdo (Marco 7), não do app.

-- Faixa 2-7 anos (docs/17 seção 2)
insert into public.task_templates
  (title, icon_key, category, suggested_period, suggested_age_min, suggested_age_max, requires_supervision)
values
  ('Guardar os brinquedos', 'toys', 'Organização', 'afternoon_evening', 2, 7, false),
  ('Colocar roupa no cesto', 'laundry_basket', 'Organização', 'anytime', 2, 7, false),
  ('Arrumar a cama com ajuda', 'bed', 'Quarto', 'morning', 2, 7, false),
  ('Escovar os dentes', 'toothbrush', 'Higiene', 'anytime', 2, 7, false),
  ('Pentear o cabelo', 'hairbrush', 'Higiene', 'morning', 2, 7, false),
  ('Vestir-se com ajuda', 'clothes', 'Autonomia', 'morning', 2, 7, false),
  ('Guardar os sapatos', 'shoes', 'Organização', 'afternoon_evening', 2, 7, false),
  ('Levar o prato até a pia', 'dishes', 'Casa', 'anytime', 2, 7, false),
  ('Ajudar a pôr a mesa', 'table_set', 'Casa', 'afternoon_evening', 2, 7, false),
  ('Regar uma planta', 'plant', 'Natureza', 'anytime', 2, 7, false),
  ('Alimentar o pet com supervisão', 'pet_food', 'Pet', 'anytime', 2, 7, true),
  ('Separar o material do dia', 'school_supplies', 'Escola', 'morning', 2, 7, false),
  ('Escolher a roupa do dia seguinte', 'clothes_next_day', 'Autonomia', 'afternoon_evening', 2, 7, false),
  ('Guardar um livro após ler', 'book', 'Organização', 'anytime', 2, 7, false),
  ('Tomar banho com supervisão', 'bath', 'Higiene', 'afternoon_evening', 2, 7, true);

-- Faixa 8-10 anos (docs/17 seção 3)
insert into public.task_templates
  (title, icon_key, category, suggested_period, suggested_age_min, suggested_age_max, requires_supervision)
values
  ('Arrumar a cama', 'bed', 'Quarto', 'morning', 8, 10, false),
  ('Organizar o material escolar', 'school_supplies', 'Escola', 'afternoon_evening', 8, 10, false),
  ('Guardar roupas limpas', 'clothes_clean', 'Organização', 'anytime', 8, 10, false),
  ('Manter o quarto organizado', 'room', 'Quarto', 'afternoon_evening', 8, 10, false),
  ('Pôr ou tirar a mesa', 'table_set', 'Casa', 'anytime', 8, 10, false),
  ('Lavar louças leves com supervisão', 'dishes_light', 'Casa', 'anytime', 8, 10, true),
  ('Passar aspirador em uma área', 'vacuum', 'Casa', 'anytime', 8, 10, false),
  ('Ajudar no preparo de comida', 'cooking', 'Cozinha', 'anytime', 8, 10, true),
  ('Regar plantas', 'plant', 'Natureza', 'anytime', 8, 10, false),
  ('Cuidar da água/comida do pet', 'pet_care', 'Pet', 'anytime', 8, 10, false),
  ('Preparar a mochila', 'backpack', 'Escola', 'afternoon_evening', 8, 10, false),
  ('Fazer a atividade escolar', 'homework', 'Escola', 'afternoon_evening', 8, 10, false),
  ('Separar roupa suja', 'laundry_sort', 'Organização', 'afternoon_evening', 8, 10, false),
  ('Ler por alguns minutos', 'reading', 'Leitura', 'anytime', 8, 10, false),
  ('Organizar jogos e materiais', 'games_organize', 'Organização', 'afternoon_evening', 8, 10, false);

-- Faixa 11-13+ (docs/17 seção 4; 13+ representado como até 17 anos)
insert into public.task_templates
  (title, icon_key, category, suggested_period, suggested_age_min, suggested_age_max, requires_supervision)
values
  ('Organizar o quarto', 'room', 'Quarto', 'anytime', 11, 17, false),
  ('Planejar tarefas da semana', 'week_plan', 'Organização', 'anytime', 11, 17, false),
  ('Preparar refeição simples com supervisão', 'cooking', 'Cozinha', 'anytime', 11, 17, true),
  ('Lavar a própria louça', 'dishes_own', 'Casa', 'anytime', 11, 17, false),
  ('Ajudar com a lavanderia', 'laundry', 'Casa', 'anytime', 11, 17, false),
  ('Limpar uma área combinada', 'clean_area', 'Casa', 'anytime', 11, 17, false),
  ('Organizar material e agenda escolar', 'school_agenda', 'Escola', 'afternoon_evening', 11, 17, false),
  ('Fazer atividade escolar', 'homework', 'Escola', 'afternoon_evening', 11, 17, false),
  ('Cuidar do pet', 'pet_care', 'Pet', 'anytime', 11, 17, false),
  ('Separar itens para o dia seguinte', 'next_day_items', 'Autonomia', 'afternoon_evening', 11, 17, false),
  ('Ler ou estudar por tempo combinado', 'study', 'Estudo', 'anytime', 11, 17, false),
  ('Ajudar a preparar a lista de compras', 'shopping_list', 'Casa', 'anytime', 11, 17, false),
  ('Retirar o lixo com orientação', 'trash', 'Casa', 'anytime', 11, 17, true),
  ('Organizar arquivos digitais escolares', 'digital_files', 'Escola', 'anytime', 11, 17, false),
  ('Conferir compromissos do dia seguinte', 'agenda_check', 'Autonomia', 'afternoon_evening', 11, 17, false);

-- Tarefas bônus de fim de semana (docs/17 seção 5)
insert into public.task_templates
  (title, icon_key, category, suggested_period, suggested_age_min, suggested_age_max, requires_supervision)
values
  ('Ajudar a lavar o carro', 'car_wash', 'Bônus', 'anytime', 8, 17, true),
  ('Organizar uma gaveta', 'drawer', 'Bônus', 'anytime', 8, 17, false),
  ('Ajudar a preparar uma receita', 'recipe', 'Bônus', 'anytime', 8, 17, true),
  ('Cuidar do jardim', 'garden', 'Bônus', 'anytime', 8, 17, true),
  ('Separar itens para doação', 'donation', 'Bônus', 'anytime', 8, 17, false),
  ('Organizar jogos da família', 'family_games', 'Bônus', 'anytime', 8, 17, false),
  ('Ajudar em uma pequena atividade doméstica', 'house_chore', 'Bônus', 'anytime', 8, 17, false),
  ('Concluir um desafio de leitura', 'reading_challenge', 'Bônus', 'anytime', 8, 17, false),
  ('Preparar um passeio com checklist', 'trip_checklist', 'Bônus', 'anytime', 8, 17, false),
  ('Ajudar a organizar compras', 'shopping_help', 'Bônus', 'anytime', 8, 17, false);
