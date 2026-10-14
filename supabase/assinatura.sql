-- Dados do cliente e assinatura da vistoria
--
-- Rode no SQL Editor do Supabase ANTES de publicar a versão do app que pede
-- nome/CPF/e-mail do cliente e colhe a assinatura.
-- Pode ser rodado mais de uma vez sem problema.

-- 1. Colunas novas em vistorias ----------------------------------------------------
-- Vistorias antigas ficam com tudo nulo (sem cliente e sem assinatura).

alter table public.vistorias
  add column if not exists cliente_nome    text,
  add column if not exists cliente_cpf     text,
  add column if not exists cliente_email   text,
  add column if not exists termo           text,         -- texto exato que o cliente aceitou
  add column if not exists assinatura_path text,         -- imagem da assinatura no Storage
  add column if not exists assinatura_hash text,         -- SHA-256 do conteúdo assinado
  add column if not exists assinatura_info jsonb,        -- aparelho, fuso, idioma, quem colheu
  add column if not exists assinado_em     timestamptz;  -- preenchido pelo banco (trigger abaixo)

-- 2. Vistoria assinada fica congelada ---------------------------------------------
-- - assinado_em vem do relógio do servidor, não do aparelho.
-- - Depois de assinada, ninguém altera dados do cliente, assinatura, termo, unidade ou planta.
-- - Só admin exclui uma vistoria assinada.
-- O status e as marcas de envio ao ClickUp continuam podendo mudar.

create or replace function public.vistorias_assinatura_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    if old.assinatura_path is not null and not public.is_admin() then
      raise exception 'Vistoria assinada não pode ser excluída.';
    end if;
    return old;
  end if;

  if old.assinatura_path is null then
    if new.assinatura_path is not null then
      new.assinado_em := now();
    end if;
    return new;
  end if;

  if new.cliente_nome    is distinct from old.cliente_nome
  or new.cliente_cpf     is distinct from old.cliente_cpf
  or new.cliente_email   is distinct from old.cliente_email
  or new.termo           is distinct from old.termo
  or new.assinatura_path is distinct from old.assinatura_path
  or new.assinatura_hash is distinct from old.assinatura_hash
  or new.assinatura_info is distinct from old.assinatura_info
  or new.assinado_em     is distinct from old.assinado_em
  or new.titulo          is distinct from old.titulo
  or new.predio          is distinct from old.predio
  or new.unidade         is distinct from old.unidade
  or new.planta_path     is distinct from old.planta_path then
    raise exception 'Vistoria assinada não pode ser alterada.';
  end if;
  return new;
end;
$$;

drop trigger if exists vistorias_assinatura_guard on public.vistorias;
create trigger vistorias_assinatura_guard
  before update or delete on public.vistorias
  for each row execute function public.vistorias_assinatura_guard();

-- 3. Defeitos de vistoria assinada também ficam congelados --------------------------
-- Não dá para incluir, apagar ou mudar o conteúdo de um defeito depois da assinatura.
-- As marcas de envio ao ClickUp (task_id, foto_ok, planta_ok, erro) continuam livres.

create or replace function public.defeitos_assinatura_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if exists (select 1 from public.vistorias v where v.id = new.vistoria_id and v.assinatura_path is not null) then
      raise exception 'Vistoria assinada não aceita novos defeitos.';
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if exists (select 1 from public.vistorias v where v.id = old.vistoria_id and v.assinatura_path is not null) then
      raise exception 'Vistoria assinada não aceita exclusão de defeitos.';
    end if;
    return old;
  end if;

  if exists (select 1 from public.vistorias v where v.id = new.vistoria_id and v.assinatura_path is not null)
  and (new.ambiente   is distinct from old.ambiente
    or new.descricao  is distinct from old.descricao
    or new.prioridade is distinct from old.prioridade
    or new.x          is distinct from old.x
    or new.y          is distinct from old.y
    or new.foto_path  is distinct from old.foto_path
    or new.n          is distinct from old.n) then
    raise exception 'Vistoria assinada não aceita alterar defeitos.';
  end if;
  return new;
end;
$$;

drop trigger if exists defeitos_assinatura_guard on public.defeitos;
create trigger defeitos_assinatura_guard
  before insert or update or delete on public.defeitos
  for each row execute function public.defeitos_assinatura_guard();
