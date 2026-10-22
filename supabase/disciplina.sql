-- Disciplina de cada defeito da vistoria
--
-- Rode no SQL Editor do Supabase ANTES de publicar a versão do app que pede a disciplina.
-- Pode ser rodado mais de uma vez. Defeitos antigos ficam com disciplina vazia;
-- ao editar um deles, o app pede a disciplina.

alter table public.defeitos add column if not exists disciplina text;
