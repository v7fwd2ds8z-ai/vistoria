-- FVS (Ficha de Verificação de Serviço)
--
-- Rode no SQL Editor do Supabase ANTES de publicar a versão do app que tem a tela de FVS.
-- Depende de supabase/aprovacao-de-acesso.sql (funções is_aprovado() e is_admin()).
-- Pode ser rodado mais de uma vez sem problema: os modelos só são inseridos se o código ainda não existir.

-- 1. Tabelas ---------------------------------------------------------------------

create table if not exists public.fvs_modelos (
  id         uuid primary key default gen_random_uuid(),
  codigo     text not null unique,
  nome       text not null,
  itens      jsonb not null default '[]'::jsonb,   -- lista de textos, na ordem da ficha
  ativo      boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fvs_inspecoes (
  id             uuid primary key default gen_random_uuid(),
  modelo_id      uuid references public.fvs_modelos(id) on delete set null,
  modelo_codigo  text not null,                    -- cópia: mudar o modelo não altera fichas antigas
  modelo_nome    text not null,
  predio         text,
  unidade        text,
  list_id        text,
  local          text,
  inspetor       text,
  data_inspecao  date not null default current_date,
  observacoes    text,
  status         text not null default 'aberta' check (status in ('aberta', 'finalizada')),
  created_by     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.fvs_itens (
  id            uuid primary key default gen_random_uuid(),
  inspecao_id   uuid not null references public.fvs_inspecoes(id) on delete cascade,
  n             int not null,
  texto         text not null,
  status        text check (status in ('NA', 'aprovado', 'reprovado', 'refeito')),  -- null = ainda não verificado
  problema      text,
  acao          text,
  liberado_por  text,
  foto_path     text,
  foto_ok       boolean not null default false,
  task_id       text,
  task_url      text,
  erro          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists fvs_itens_inspecao_idx on public.fvs_itens (inspecao_id, n);

alter table public.fvs_modelos enable row level security;
alter table public.fvs_inspecoes enable row level security;
alter table public.fvs_itens enable row level security;

-- 2. Regras de acesso ----------------------------------------------------------------
-- Modelos: aprovados leem, só admin altera. Fichas e itens: aprovados fazem tudo.

drop policy if exists "fvs_modelos select" on public.fvs_modelos;
drop policy if exists "fvs_modelos insert" on public.fvs_modelos;
drop policy if exists "fvs_modelos update" on public.fvs_modelos;
drop policy if exists "fvs_modelos delete" on public.fvs_modelos;
create policy "fvs_modelos select" on public.fvs_modelos for select to authenticated using (public.is_aprovado());
create policy "fvs_modelos insert" on public.fvs_modelos for insert to authenticated with check (public.is_admin());
create policy "fvs_modelos update" on public.fvs_modelos for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "fvs_modelos delete" on public.fvs_modelos for delete to authenticated using (public.is_admin());

drop policy if exists "fvs_inspecoes select" on public.fvs_inspecoes;
drop policy if exists "fvs_inspecoes insert" on public.fvs_inspecoes;
drop policy if exists "fvs_inspecoes update" on public.fvs_inspecoes;
drop policy if exists "fvs_inspecoes delete" on public.fvs_inspecoes;
create policy "fvs_inspecoes select" on public.fvs_inspecoes for select to authenticated using (public.is_aprovado());
create policy "fvs_inspecoes insert" on public.fvs_inspecoes for insert to authenticated with check (public.is_aprovado());
create policy "fvs_inspecoes update" on public.fvs_inspecoes for update to authenticated using (public.is_aprovado()) with check (public.is_aprovado());
create policy "fvs_inspecoes delete" on public.fvs_inspecoes for delete to authenticated using (public.is_aprovado());

drop policy if exists "fvs_itens select" on public.fvs_itens;
drop policy if exists "fvs_itens insert" on public.fvs_itens;
drop policy if exists "fvs_itens update" on public.fvs_itens;
drop policy if exists "fvs_itens delete" on public.fvs_itens;
create policy "fvs_itens select" on public.fvs_itens for select to authenticated using (public.is_aprovado());
create policy "fvs_itens insert" on public.fvs_itens for insert to authenticated with check (public.is_aprovado());
create policy "fvs_itens update" on public.fvs_itens for update to authenticated using (public.is_aprovado()) with check (public.is_aprovado());
create policy "fvs_itens delete" on public.fvs_itens for delete to authenticated using (public.is_aprovado());

-- 3. Realtime ------------------------------------------------------------------------

do $$
begin
  alter publication supabase_realtime add table public.fvs_modelos;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.fvs_inspecoes;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.fvs_itens;
exception when duplicate_object then null;
end $$;

-- 4. Modelos iniciais (31 fichas do PBQP-H) ----------------------------------------------
-- Depois de rodar, admins editam os modelos pelo app (menu > Modelos de FVS).

insert into public.fvs_modelos (codigo, nome, itens) values ($c$001$c$, $n$Compactação de aterro$n$, $j$["Há a utilização de EPI´s e EPC´s?", "Preparo do terreno para receber o aterro? (No caso de solos argilosos, não executar compactação com o solo úmido)", "O espalhamento do material foi executado corretamente?", "A camada foi compactada nas proximidades dos elementos rígidos?", "As demais áreas foram compactadas?", "Uma próxima camada foi colocada?", "O nivelamento final está correto?", "A umidade está no grau correto?"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$002$c$, $n$Locação da obra$n$, $j$["Utilização de EPI´s e EPC´s", "Demarcação do alinhamento predial e divisas", "Nivelamento do gabarito em relação ao nível inicial", "Execução de tapumes / placas", "Execução das instalações provisórias", "Gabarito e marcação dos eixos", "Execução a marcação dos eixos de acordo com as medidas do projeto (Parâmetro = no alinhamento)", "Marcação dos elementos estruturais, alinhamento de paredes e identificação no gabarito", "Esquadros e cotas", "Locação das estacas", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$003$c$, $n$Execução de fundação - estacas, blocos e baldrame$n$, $j$["Utilização de EPI´s e EPC´s", "Levantamento de risco entre construções vizinhas e existência de documentação de vistoria cautelar", "Locação das estacas, diâmetros e cotas de arrasamento - Esquadro do gabarito – na execução (Conferir nas laterais do gabarito – tolerância = 20 mm)", "Execução e posicionamento de armaduras", "Alargamento da base, presença de água, execução de concretagem, intervalo entre escavação e concretagem", "Prumo de estaca pré-moldada, quebra na cravação, alcançar a nega das estacas", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$004$c$, $n$Execução de fôrmas$n$, $j$["Utilização de EPI´s e EPC´s", "Locação, posicionamento, nível e prumo de acordo com o projeto (Parâmetro = 5mm tolerância – entre as caixas e no prumo e níveis).", "Travamento, amarração e escoramento", "Aberturas para futuras passagens de hidráulica, fixação de eletrodutos e posicionamento correto de caixa elétricas", "Limpeza e aplicação do desmoldante", "Contínuo escoramento de lajes e vigas ainda não curadas", "Desforma", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$005$c$, $n$Montagem de armadura$n$, $j$["Utilização de EPI´s e EPC´s", "Identificação de toda a armadura", "Dimensão bitola, posicionamento das ferragens e armação", "A dobra e o corte estão conforme o projeto (Tolerância +/- 0,5 cm / Parâmetro = na dobra do corte)", "Armadura conforme projeto estrutural, espaçamento dos estribos, quantidade de aços posicionados no positivo e negativo (Tolerância espaçamento =/- 1 cm / Parâmetro para estribos e armaduras)", "Amarração", "Espaçamento, espaçadores e encabeçamento de vigas", "Acesso para o mangote vibrador", "Proteção de pontas expostas, proteção periférica, proteção de armaduras negativas (passarelas provisórias)", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$006$c$, $n$Concretagem de peça estrutural$n$, $j$["Utilização de EPI´s e EPC´s", "Verificar o efetivo umedecimento das fôrmas sem excessos.", "Verificar o sarrafeamento do concreto e desempeno com madeira.", "Foi verificado a regularidade da umidade das camadas protetoras nos 3 primeiros dias no mínimo.", "Verificar a possibilidade de programar a junta, bem como observar para a junta não coincidir com os planos de cisalhamento.", "Foram moldados corpos de prova desta concretagem", "O slump/abatimento está de acordo com o esperado", "Respeitar o tempo máximo para utilização do concreto desde a adição da água de amassamento – para concreto usinado consultar a NF", "No lançamento respeitar a altura de queda do concreto (Tolerância = Max: 2 m, quanto mais próximo melhor", "Respeitar a cura (Tolerância = Mín. 7 dias após o lançamento do concreto) ou atingimento do fck mínimo"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$007$c$, $n$Execução de alvenaria estrutural$n$, $j$["Utilização de EPI´s e EPC´s", "Nivelamento e alinhamento da fiada de marcação - Através de nível de mangueira ou laser, trena e linha de náilon após marcação concluída 3 mm em 5 metros", "Planeza e prumo da alvenaria (ambiente interno) - Através de um prumo de face e régua de alumínio de 2 metros após a conclusão da elevação da alvenaria ± 3 mm", "Largura e altura dos vãos de portas e janelas Através de trena metálica após a conclusão da elevação da alvenaria ± 8 mm", "Aspecto final e coroamento ou respaldo Visual após a conclusão da alvenaria"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$008$c$, $n$Execução de alvenaria não estrutural e de divisória leve$n$, $j$["Utilização de EPI´s e EPC´s", "O alinhamento está correto?", "O prumo está correto?", "As aberturas estão corretas?", "As medidas estão corretas?", "Os níveis estão corretos?", "A amarração está correta?", "O travamento foi executado corretamente?", "O local foi limpo após o serviço?"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$009$c$, $n$Execução de revestimento interno de área seca$n$, $j$["Utilização de EPI´s e EPC´s", "O esquadro dos ambientes está correto (talisca)?", "O prumo das paredes está correto (talisca)?", "O acabamento das paredes no encontro com teto e piso está correto?", "Há proteção de esquadrias?", "A laje acabada tem o nivelamento correto?", "Cura do chapisco?", "Acabamento superficial pronto para cerâmica ou pintura?", "Limpeza e proteção do piso?"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$010$c$, $n$Execução de revestimento interno de área úmida$n$, $j$["Utilização de EPI´s e EPC´s", "A superfície está plana?", "O nível do piso está correto?", "Os níveis dos cantos de teto estão correto?", "O comprimento das paredes está correto?", "As juntas possuem espessura e alinhamentos corretos?", "As peças assentadas tem a planicidade correta?", "As peças quebradas e soltas foram substituídas?", "As juntas estão limpas?", "O esquadrejamento do ambiente está correto?", "O revestimento está alinhado?", "O revestimento está com o acabamento correto?", "As juntas foram limpas antes da aplicação do rejunte?", "O acabamento final foi efetuado com o alisamento das juntas?", "Houve a limpeza final após a execução do serviço?"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$011$c$, $n$Execução de revestimento externo$n$, $j$["Utilização de EPI´s e EPC´s", "Preparação da base: visual, verificar, se há imperfeições na base que possuam comprometer a qualidade do serviço.", "Aplicação: verificar visualmente o acabamento final do chapisco.", "Aspecto final: Verificar o acabamento do pano, seguindo especificação do projeto (sarraceno ou desempenado). Tolerância: para sarraceno máx. 2mm e para desempenado sem tolerância.", "Caimento em vão de janelas: Caimento deverá ser para fora da janela, conferir com nível bolha. Tolerância: desnível de 2mm para fora.", "Acabamento: verificar posicionamento do ponto de água fria, deverá ficar faceado com o reboco ou 05mm para fora.", "Limpeza e Organização: limpar toda área após o serviço concluído. Caso tenha resquícios de argamassa nas paredes, remover os resíduos."]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$012$c$, $n$Execução de contrapiso$n$, $j$["Utilização de EPI´s e EPC´s?", "Instalações hidráulicas, elétricas e nichos concluídos?", "Limpeza do local antes do início da pavimentação e condições da superfície?", "Traço da argamassa de acordo com o revestimento a ser recebido?", "Nível e planicidade do piso, rebaixos, e caimento para ralos e calhas?", "Acabamento para o fim que se destina?", "Limpeza do ambiente e equipamentos de trabalho?"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$013$c$, $n$Execução de revestimento de piso interno de área seca$n$, $j$["Utilização de EPI´s e EPC´s", "Visualmente, antes do rejunte: Planeza do", "revestimento", "Espessura das juntas", "Presença de dentes e saliências entre as", "Peças desvio max. 2 mm", "Espessura da junta", "Distribuição das peças", "Cor uniforme e limpeza", "Aderência da argamassa", "Passar massa atrás da peça (≥ 30x30 cm)", "Acabamento dos recortes", "Planicidade", "Alinhamento nos dois sentidos", "Limpeza das peças", "Caimento", "Limpeza dos ralos e grelhas - A parte interna das caixas (sifonadas e secas)", "deve estar limpa sem restos de argamassa.", "As grelhas dos ralos devem estar limpas", "Limpeza do local e proteção"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$014$c$, $n$Execução de revestimento de piso interno de área úmida$n$, $j$["Utilização de EPI´s e EPC´s", "Paginação (projeto de paginação)", "Instalação elétrica, hidráulica e nichos concluídos", "Superfície onde será aplicada a cerâmica está limpa, regular, aderente e sem sinais de vazamentos", "Argamassa de assentamento (amassamento conforme especificação do fabricante)", "Peças quanto ao lote de fabricação, homogeneidade, cantos e planicidade", "Assentamento, alinhamento, prumo das juntas e planicidade", "Alinhamento e caimento para ralos", "Limpeza das juntas e aplicação do rejunte 72h após colocação, e limpeza final da superfície", "Proteção do local com plástico bolha, lona, papelão outra forma.", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$015$c$, $n$Execução de revestimento de piso externo$n$, $j$["Utilização de EPI´s e EPC´s", "Paginação", "Instalação elétrica, hidráulica e nichos concluídos", "Superfície onde será aplicada a cerâmica está limpa, regular, aderente e sem sinais de vazamentos", "Argamassa de assentamento", "Peças quanto ao lote de fabricação, homogeneidade, cantos e planicidade", "Assentamento, alinhamento, prumo das juntas e planicidade", "Alinhamento e caimento para ralos", "Limpeza das juntas e aplicação do rejunte 48h após colocação, e limpeza final da superfície", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$016$c$, $n$Execução de forro de gesso$n$, $j$["Utilização de EPI´s e EPC´s", "O projeto de detalhamento do forro foi seguido?", "O forro está devidamente nivelado?", "A área está preparada para receber o gesso?", "As esquadrias, louças e pisos estão devidamente isolados?", "Pontos de elétricas estão a mostra?", "O forro de gesso está liso e sem rebarba?", "A área está limpa e com os dejetos recebendo a destinação correta?"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$017$c$, $n$Execução de impermeabilização e teste de estanqueidade$n$, $j$["Utilização de EPI´s e EPC´s", "Regularização da superfície a ser impermeabilizada com caimento para ralos e calhas", "Aplicação de \"praimer\" (uma demão) - (cobertura total da área a ser impermeabilizada)", "Aplicação da manta por colagem, aquecendo o material com maçarico", "Verificação das sobreposições (verificar largura de sobreposição de acordo com o fabricante - as sobreposições devem estar favoráveis ao escoamento d'água)", "Verificação da aderência 100% trena verificar largura de sobreposição de acordo com o fabricante - as sobreposições devem estar favoráveis ao escoamento d'água - com boa aderência", "Aplicação de tela galvanizada nas áreas verticais (exceto caixa d'água) sobre a manta asfática (deve estar bem fixada com pedaços de manta ou pinos de aço)", "Verificação da manta nos ralos (deve estar bem aderida nas paredes internas da tubulação a uma profundidade maior ou igual a 5 cm)", "Verificação de pontos de interferência (base para suporte, tubos emergentes, chumbadores) - devem ter sido arrematados com material impermeabilizante", "Teste de estanqueidade: sem variação do volume d'água, com carga total de água durante 72 horas (fachadas, pisos de locais molhados, coberturas, instalações hidrossanitárias e demais elementos sujeitos ao uso de água)", "Sem vazamentos e sinais de infiltrações após teste de estanqueidade, observando a ausência de infiltração nos pisos e paredes adjacentes, o sistema poderá ser liberado.", "Proteção mecânica (cobrimento total da impermeabilização, com auxílio de tela galvanizada)"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$017.1$c$, $n$Execução de impermeabilização de lajes, calhas, jardineiras, caixas d'água e piscinas$n$, $j$["Utilização de EPI´s e EPC´s", "Regularização da superfície a ser impermeabilizada com caimento para ralos e calhas", "Aplicação de \"praimer\" (uma demão) - (cobertura total da área a ser impermeabilizada)", "Aplicação da manta por colagem, aquecendo o material com maçarico", "Verificação das sobreposições (verificar largura de sobreposição de acordo com o fabricante - as sobreposições devem estar favoráveis ao escoamento d'água)", "Verificação da aderência 100% trena verificar largura de sobreposição de acordo com o fabricante - as sobreposições devem estar favoráveis ao escoamento d'água - com boa aderência", "Aplicação de tela galvanizada nas áreas verticais (exceto caixa d'água) sobre a manta asfática (deve estar bem fixada com pedaços de manta ou pinos de aço)", "Verificação da manta nos ralos (deve estar bem aderida nas paredes internas da tubulação a uma profundidade maior ou igual a 5 cm)", "Verificação de pontos de interferência (base para suporte, tubos emergentes, chumbadores) - devem ter sido arrematados com material impermeabilizante", "Teste de estanqueidade (não deve haver vazamento após 72 horas em teste)", "Proteção mecânica (cobrimento total da impermeabilização, com auxílio de tela galvanizada)"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$018$c$, $n$Execução de cobertura - estrutura e telhamento - fibrocimento$n$, $j$["Utilização de EPI´s e EPC´s", "Local preparado e limpo, planejamento da inclinação da estrutura", "Instalação das mantas (se houverem) antes do ripamento", "Sentido de telhamento (horizontal e vertical)", "Encaixe e sobreposição das telhas", "As fixações foram feitas com parafusos, pinos ou prego", "Telhas alinhadas, não encavaladas, recortes perfeitos, e sem falhas", "Verificar as calhas e condutores", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$019$c$, $n$Colocação de batente e portas$n$, $j$["Utilização de EPI´s e EPC´s", "Vãos das esquadrias, espessura das paredes e alinhamento do contramarco em relação a face das paredes", "Prumo e nivelamento", "Requadro do vão", "Colocação, vedação e funcionamento", "Colocação dos vidros e limpeza da esquadria", "Pintura da esquadria", "Vãos, espessura das paredes para os caixilhos, tipos de fechaduras e sentido de abertura da porta", "Caixilhos bem aprumados, alinhados e bem fixados, homogeneidade de cor e desenho com a porta e conjuntos próximos", "Dobradiças correspondem ao peso da porta e estão uniformemente distribuídas, altura da fechadura", "Verificação de folgas na altura, lateral e inferior", "Espaçamento em relação ao piso", "Colocação das vistas, guarnições, acabamento geral e proteção", "Colocação dos rodapés", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$020$c$, $n$Colocação de janelas$n$, $j$["Utilização de EPI´s e EPC´s", "Vãos das esquadrias, espessura das paredes e alinhamento do contramarco em relação a face das paredes", "Prumo e nivelamento", "Requadro do vão", "Colocação, vedação e funcionamento", "Colocação dos vidros e limpeza da esquadria", "Pintura da esquadria", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$021$c$, $n$Execução de guarda corpo$n$, $j$["Utilização de EPI´s e EPC´s", "A altura mínima do guarda-corpo, considerada entre o piso acabado e a parte superior do peitoril, é de 1 100 mm? Se a altura da mureta for menor ou igual a 200 mm ou maior que 800 mm, a altura total é de no mínimo 1 100 mm?", "Alinhamento marcação", "Limpeza da furação", "Recomposição impermeabilização", "Deformação / Ruptura?", "Proteção ao término do serviço"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$022$c$, $n$Pintura interna$n$, $j$["Utilização de EPI´s e EPC´s", "Especificações (cores, acabamentos, etc.)", "Ambiente preparado, fechado, as paredes e tetos sem imperfeições, umidade e limpos", "Esquadrias, pisos, acabamentos hidráulicos e elétricos protegidos", "Cobrimento uniforme, homogêneo e acabamento da superfície", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$023$c$, $n$Pintura externa$n$, $j$["Utilização de EPI´s e EPC´s", "Especificações (cores, acabamentos, etc.)", "Ambiente preparado, fechado, as paredes e tetos sem imperfeições, umidade e limpos", "Esquadrias, pisos, acabamentos hidráulicos e elétricos protegidos", "Cobrimento uniforme, homogêneo e acabamento da superfície", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$024$c$, $n$Instalações elétrica e telefônica$n$, $j$["Utilização de EPI´s e EPC´s", "Marcação dos pontos e eletrodutos posicionados na forma da menor distância entre os pontos", "Caixas e quadros embutidos no nível, alinhados, prumados e compatível com a espessura do revestimento e fixados", "Eletrodutos e caixas protegidos contra eventual entrada de caliça", "Limpeza das tubulações, caixas e quadros", "Emendas de fios e cabos realizadas dentro das caixas e bem isoladas", "Parafusos de fixação dos fios, cabos, disjuntores e terminais bem apertados", "Acabamento de tomadas, interruptores e interfones estão instalações e alinhados", "Identificação do quadro de distribuição", "Limpeza do ambiente e equipamentos de trabalho"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$024.1$c$, $n$Instalações elétricas para-raio - aterramento$n$, $j$["Utilização de EPI´s e EPC´s", "Para-Raios – Tipo", "Malha de aterramento – Bitola de cabos", "Malha de aterramento - Quantidade de hastes", "Descidas – Quantidade", "Descidas - Bitola de cabos", "Malha de cobertura – Espaçamento", "Malha de cobertura - Bitola dos Cabos", "Malha de cobertura - Quantidade de Captores", "Resistência de aterramento (tolerância Resistência R < 10 Ohm)", "Documentação – ART do sistema (o empreiteiro deve fornecer esse documento)"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$024.2$c$, $n$Instalações elétricas - recebimento de instalações elétricas$n$, $j$["Utilização de EPI´s e EPC´s", "Instalações - Locação dos pontos elétricos (Laje) – (tolerância ± 10mm não afetando o alinhamento)", "Instalações - Posição e alinhamento dos pontos (parede)", "Instalações - Desentupimento das instalações (deve estar desobstruído)", "Instalações - Identificação no quadro de luz - circuitos e informações) (Devem estar identificados)", "Instalações - Teste dos pontos elétricos", "Telefonia e lógica - Dimensão e posicionamento dos quadros", "Telefonia e lógica - Desentupimento das instalações (deve estar desobstruído)"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$025$c$, $n$Instalações hidro-sanitária - esgoto$n$, $j$["Utilização de EPI´s e EPC´s", "Checar se o projeto de instalação está concluído e completo.", "Verificar se todas alvenarias estão concluídas (sem rebarbas ou fissuras) e fixadas.", "Assegurar a limpeza local.", "Instalar as prumadas da rede de esgoto de acordo com o projeto.", "Conectar as tubulações, lubrificando-as para melhor encaixe.", "Instalar os ramais aéreos de esgoto, obedecendo o espaçamento necessário previsto em projeto.", "Amarrar o ramal de esgoto à laje com fita metálica perfurada.", "As pontas das tubulações deverão ser tampadas para evitar que entre algum tipo de material e venham a entupir."]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$026$c$, $n$Instalação de gás$n$, $j$["Utilização de EPI´s e EPC´s", "Tubulações (dimensões / diâmetro)", "Instalações - Corte no emboço (sem desperdício)", "Instalações - Locação do ponto (tolerância ± 10mm)", "Instalações - Verificar as fixações antes do revestimento ou isolamento", "Instalações - Verificar ventilação", "Exigir foto do caminhamento", "Teste de estanqueidade com a rede aparente e/ou embutida (Gás Natural) - Prumadas: Com manômetro - pressão de 3 kgf/cm² Ramais: Com régua de coluna d'água - pressão de 500 mm.c.a (tolerância - não apresentar vazamentos. Durante", "12h não deve cair a pressão)", "Teste de estanqueidade – abrigo regulador de entrada de gás (Gás Natural) - Com régua de coluna d'água - pressão de 500 mm.c.a. (somente", "com as tubulações finalizadas) (tolerância não apresentar vazamentos durante 1h não deve cair a pressão)", "Teste de estanqueidade com a rede aparente e/ou embutida (GLP) - Pressão de 6 Kgf/cm² para redes primárias (toda rede anterior ao regulador de pressão) 1 kgf/cm² para rede secundária (tolerância não apresentar vazamentos. Durante", "12h não deve cair a pressão)"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$027$c$, $n$Colocação de bancada, louça e metal sanitário$n$, $j$["Utilização de EPI´s e EPC´s", "Checar se o projeto de instalação está concluído e completo.", "Instalação das louças e cubas estão firmes e niveladas", "Sifão e engates bem presos e testados contra vazamentos", "Teste de torneiras e caixas acopladas e suas vedações", "Acabamentos de registro ficaram nivelados e bem encaixados com a parede", "Saídas de água estão testadas e livres de sujeiras e impurezas", "Assegurar a limpeza local.", "Nivelamento do vaso sanitário"]$j$::jsonb)
  on conflict (codigo) do nothing;
insert into public.fvs_modelos (codigo, nome, itens) values ($c$028$c$, $n$Laje pré-moldada + vigas$n$, $j$["Utilização de EPI´s e EPC´s", "Verificar se a armadura das vigas está de acordo com o projeto estrutural", "Verificar se a montagem da laje pré-moldada está de acordo com o projeto", "Verificar se o traço do concreto está der acordo com o projeto", "Concretagem da peça de uma só vez", "Foram moldados corpos de prova desta concretagem", "Verificar se a nivelação da laje foi executada com qualidade aceitável", "Respeitar o tempo máximo para utilização do concreto desde a adição da água de amassamento – para concreto usinado consultar a NF", "No lançamento respeitar a altura de queda do concreto (Tolerância = Max: 2 m, quanto mais próximo melhor", "Respeitar a cura (Tolerância = Mín. 7 dias após o lançamento do concreto) ou atingimento do fck mínimo"]$j$::jsonb)
  on conflict (codigo) do nothing;
