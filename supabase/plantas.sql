-- Biblioteca de plantas
--
-- Rode no SQL Editor do Supabase ANTES de publicar a versão do app que tem a
-- "Biblioteca de plantas". Depende de supabase/aprovacao-de-acesso.sql
-- (funções is_aprovado() e is_admin()). Pode ser rodado mais de uma vez.
--
-- Uma planta por prédio + unidade, com os mesmos nomes do ClickUp (pasta e lista).
-- O arquivo fica no bucket `vistoria-files` (prefixo `plantas/`); a vistoria que
-- usa uma planta guarda o caminho do arquivo, então trocar a planta da biblioteca
-- não altera vistorias antigas.

create table if not exists public.plantas (
  id          uuid primary key default gen_random_uuid(),
  predio      text not null,
  unidade     text not null,
  planta_path text not null,
  created_by  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (predio, unidade)
);

alter table public.plantas enable row level security;

drop policy if exists "plantas select" on public.plantas;
drop policy if exists "plantas insert" on public.plantas;
drop policy if exists "plantas update" on public.plantas;
drop policy if exists "plantas delete" on public.plantas;
create policy "plantas select" on public.plantas for select to authenticated using (public.is_aprovado());
create policy "plantas insert" on public.plantas for insert to authenticated with check (public.is_admin());
create policy "plantas update" on public.plantas for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "plantas delete" on public.plantas for delete to authenticated using (public.is_admin());
