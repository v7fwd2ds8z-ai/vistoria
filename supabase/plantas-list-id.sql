-- Planta da biblioteca ligada à lista do ClickUp pelo ID, não pelo nome
--
-- Rode no SQL Editor do Supabase ANTES de publicar a versão do app que casa a
-- planta por list_id. Depende de supabase/plantas.sql. Pode ser rodado mais de uma vez.
--
-- Renomear pasta ou lista no ClickUp não muda o ID, então a planta continua
-- aparecendo. As colunas predio/unidade ficam como nome de exibição e como
-- plano B (plantas sem list_id ainda casam pelo nome).

alter table public.plantas add column if not exists list_id text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'plantas_list_id_key') then
    alter table public.plantas add constraint plantas_list_id_key unique (list_id);
  end if;
end $$;

-- Preenche o list_id das plantas já cadastradas (nomes e IDs do ClickUp em 23/11/2026).
update public.plantas p
   set list_id = v.list_id
  from (values
    ('AOI', 'UD 101', '901114762831'),
    ('AOI', 'UD 102', '901114762833'),
    ('AOI', 'UD 103', '901114762834'),
    ('AOI', 'UD 104', '901114762836'),
    ('AOI', 'UD 105', '901114762837'),
    ('AOI', 'UD 106', '901114762839'),
    ('AOI', 'UD 201', '901114762842'),
    ('AOI', 'UD 202', '901114762843'),
    ('AOI', 'UD 203', '901114762844'),
    ('AOI', 'UD 204', '901114762845'),
    ('AOI', 'UD 205', '901114762846'),
    ('AOI', 'UD 206', '901114762847'),
    ('AOI', 'UD 207', '901114762848'),
    ('AOI', 'UD 301', '901114762851'),
    ('AOI', 'UD 302', '901114762852'),
    ('AOI', 'UD 303', '901114762854'),
    ('AOI', 'UD 304', '901114762855'),
    ('AOI', 'UD 305', '901114762856'),
    ('AOI', 'UD 401', '901114762858'),
    ('AOI', 'UD 402', '901114762859'),
    ('AOI', 'UD 403', '901114762860'),
    ('AOI', 'UD 404', '901114762861'),
    ('AOI', 'UD 405', '901114762863'),
    ('AOI', 'UD 501', '901114762865'),
    ('AOI', 'UD 502', '901114762872'),
    ('AOI', 'UD 503', '901114762876'),
    ('AOI', 'UD 504', '901114762877'),
    ('AOI', 'UD 505', '901114762878'),
    ('AOI', 'UD 601', '901114762881'),
    ('AOI', 'UD 602', '901114762882'),
    ('AOI', 'UD 603', '901114762884'),
    ('AOI', 'UD 604', '901114762887'),
    ('AOI', 'UD 701', '901114762890'),
    ('AOI', 'UD 702', '901114762891'),
    ('AOI', 'UD 703', '901114762895'),
    ('AOI', 'UD 704', '901114762896'),
    ('Santorini', 'UD 01', '901114762769'),
    ('Santorini', 'UD 02', '901114762753'),
    ('Santorini', 'UD 03', '901114762778'),
    ('Santorini', 'UD 04', '901114762782'),
    ('Paris', 'UD 01', '901114762977'),
    ('Paris', 'UD 02', '901114762995'),
    ('Paris', 'UD 03', '901114762996'),
    ('Mykonos', 'UD 01', '901114763205'),
    ('Mykonos', 'UD 02', '901114763206'),
    ('Mykonos', 'UD 03', '901114763208'),
    ('Mykonos', 'UD 04', '901114763209'),
    ('Ópera Tingui', 'UD 01', '901114763339'),
    ('Ópera Tingui', 'UD 02', '901114763341'),
    ('Ópera Tingui', 'UD 03', '901114763342'),
    ('Ópera Tingui', 'UD 04', '901114763343')
  ) as v(predio, unidade, list_id)
 where p.list_id is null and p.predio = v.predio and p.unidade = v.unidade;

-- Conferência: deve voltar vazio (plantas que ainda não casaram com uma lista).
select predio, unidade from public.plantas where list_id is null;
