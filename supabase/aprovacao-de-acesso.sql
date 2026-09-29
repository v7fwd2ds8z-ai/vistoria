-- Aprovação de novos acessos
--
-- Rode no SQL Editor do Supabase ANTES de publicar a versão do app que usa a
-- tabela `usuarios` e ANTES de ativar "Allow new users to sign up".
-- Pode ser rodado mais de uma vez sem problema.
--
-- Depois de rodar, marque você como admin (último comando, troque o e-mail).

-- 1. Tabela de usuários e seus status -----------------------------------------

create table if not exists public.usuarios (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  email        text not null,
  nome         text,
  status       text not null default 'pendente' check (status in ('pendente', 'aprovado', 'recusado')),
  admin        boolean not null default false,
  created_at   timestamptz not null default now(),
  decidido_em  timestamptz,
  decidido_por uuid references auth.users(id) on delete set null
);

alter table public.usuarios enable row level security;

-- 2. Funções usadas pelas regras de acesso -------------------------------------
-- security definer: leem `usuarios` sem passar pelo RLS (evita recursão).

create or replace function public.is_aprovado() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.usuarios where user_id = auth.uid() and status = 'aprovado'
  );
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.usuarios where user_id = auth.uid() and status = 'aprovado' and admin
  );
$$;

-- 3. Todo usuário novo do Auth vira um pedido pendente -------------------------

create or replace function public.criar_pedido_acesso() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.usuarios (user_id, email, nome)
  values (
    new.id,
    coalesce(new.email, ''),
    nullif(trim(left(new.raw_user_meta_data ->> 'nome', 120)), '')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_pedido on auth.users;
create trigger on_auth_user_created_pedido
  after insert on auth.users
  for each row execute function public.criar_pedido_acesso();

-- 4. Quem já tem conta hoje continua com acesso --------------------------------

insert into public.usuarios (user_id, email, status, decidido_em)
select id, coalesce(email, ''), 'aprovado', now() from auth.users
on conflict (user_id) do nothing;

-- 5. Regras da tabela usuarios -------------------------------------------------
-- Cada um vê o próprio registro; admin vê todos. Só admin altera (aprovar/recusar).
-- Ninguém insere nem apaga pelo app: a inserção vem do trigger acima.

drop policy if exists "usuarios select" on public.usuarios;
create policy "usuarios select" on public.usuarios for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "usuarios update" on public.usuarios;
create policy "usuarios update" on public.usuarios for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 6. Vistorias, defeitos e arquivos: só para aprovados -------------------------
-- Antes era "qualquer usuário logado" (true).

drop policy if exists "vistorias select" on public.vistorias;
drop policy if exists "vistorias insert" on public.vistorias;
drop policy if exists "vistorias update" on public.vistorias;
drop policy if exists "vistorias delete" on public.vistorias;
create policy "vistorias select" on public.vistorias for select to authenticated using (public.is_aprovado());
create policy "vistorias insert" on public.vistorias for insert to authenticated with check (public.is_aprovado());
create policy "vistorias update" on public.vistorias for update to authenticated using (public.is_aprovado()) with check (public.is_aprovado());
create policy "vistorias delete" on public.vistorias for delete to authenticated using (public.is_aprovado());

drop policy if exists "defeitos select" on public.defeitos;
drop policy if exists "defeitos insert" on public.defeitos;
drop policy if exists "defeitos update" on public.defeitos;
drop policy if exists "defeitos delete" on public.defeitos;
create policy "defeitos select" on public.defeitos for select to authenticated using (public.is_aprovado());
create policy "defeitos insert" on public.defeitos for insert to authenticated with check (public.is_aprovado());
create policy "defeitos update" on public.defeitos for update to authenticated using (public.is_aprovado()) with check (public.is_aprovado());
create policy "defeitos delete" on public.defeitos for delete to authenticated using (public.is_aprovado());

drop policy if exists "arquivos select" on storage.objects;
drop policy if exists "arquivos insert" on storage.objects;
drop policy if exists "arquivos update" on storage.objects;
drop policy if exists "arquivos delete" on storage.objects;
create policy "arquivos select" on storage.objects for select to authenticated
  using (bucket_id = 'vistoria-files' and public.is_aprovado());
create policy "arquivos insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'vistoria-files' and public.is_aprovado());
create policy "arquivos update" on storage.objects for update to authenticated
  using (bucket_id = 'vistoria-files' and public.is_aprovado())
  with check (bucket_id = 'vistoria-files' and public.is_aprovado());
create policy "arquivos delete" on storage.objects for delete to authenticated
  using (bucket_id = 'vistoria-files' and public.is_aprovado());

-- 7. Realtime: a tela de espera e o contador do admin atualizam sozinhos -------

do $$
begin
  alter publication supabase_realtime add table public.usuarios;
exception when duplicate_object then null;
end $$;

-- 8. Marque você como admin (troque pelo seu e-mail) ---------------------------

update public.usuarios set admin = true where email = 'SEU-EMAIL@exemplo.com';
