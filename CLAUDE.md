# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão geral

App web de página única para vistoria de entrega de unidades: o usuário envia a planta, toca nela para marcar defeitos (ambiente, descrição, prioridade, foto) e envia cada ponto como task ao ClickUp. Todo o app (HTML, CSS e JS) está em `index.html`; `LEIA-ME.md` tem as instruções de configuração para humanos. Interface e textos em pt-BR.

## Rodar

Não há build, dependências, lint nem testes. Sirva a pasta estaticamente:

    python3 -m http.server 5173

(`.claude/launch.json` já define o servidor `vistoria` na porta 5173.) O login por link mágico só funciona se a URL local estiver nos *Redirect URLs* do Supabase.

## Serviços externos

- **Supabase** (via `@supabase/supabase-js@2` UMD do jsDelivr): Auth por link mágico com `shouldCreateUser: false` (só entram e-mails cadastrados no painel); tabelas `vistorias` e `defeitos`; bucket de Storage `vistoria-files` (prefixos `plantas/` e `fotos/`, sempre JPEG). Arquivos são lidos por signed URLs (TTL de 6h, com cache em `urlCache`).
- **ClickUp** por um proxy em Cloudflare Worker (`API_BASE`), que não está neste repositório. `API_BASE + '/auth/start'` inicia o OAuth; o Worker redireciona de volta com `#token=...` ou `#erro=...` no hash, lido em `readClickUpHash()` e salvo em `localStorage` (`vst_token`). As chamadas passam por `cu(path)` → `API_BASE/api/<path>` com `Bearer token`.
- A configuração fica no topo do `<script>` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE`, `BUCKET`). O arquivo é público: use só a chave `anon`, nunca a `service_role`.
- pdf.js é carregado sob demanda do cdnjs apenas quando a planta é PDF (usa só a primeira página).

## Arquitetura do JS

Uma IIFE com JS no estilo ES5 (`var`, `function`, concatenação de strings) mais `async/await`. Mantenha esse estilo.

- **Estado global único** `state`; a navegação é por `state.view` (`home` | `novo` | `vistoria` | `relatorio`), sem roteador nem URL.
- **Renderização**: `render()` reconstrói `#root.innerHTML` a partir de funções `view*()` que retornam strings HTML, e depois chama `wireForms()` para religar os listeners de `change` (os elementos são recriados a cada render). Todo valor interpolado precisa passar por `esc()`. O scroll da planta é preservado manualmente em `render()`.
- **Eventos**: um único listener de `click` no documento, que despacha por atributos `data-act` (`data-id` para o alvo). Para adicionar uma ação, crie um botão com `data-act` e um ramo nesse `if/else`.
- **Bottom sheet** de defeito é renderizado em `#overlay` via `sheetHtml()`; modos `novo` / `editar` / `ver` (depois que existe `task_id` o ponto fica somente leitura).
- **Marcação na planta**: `pointerdown`/`pointerup` com limite de movimento (8px) e tempo (600ms) para diferenciar toque de arrasto/scroll; as coordenadas são salvas **normalizadas (0–1)** em `defeitos.x/y` e os pinos são posicionados em `%`.
- **Dados**: `loadAll()` busca todas as vistorias e defeitos e junta no cliente (`v.defeitos`). Campos com `_` (`_plantaUrl`, `_fotoUrl`) são só do cliente e não vão para o banco. O Realtime do Supabase em ambas as tabelas chama `scheduleReload()` (debounce de 400ms → `loadAll`).
- **Status**: `isComplete(d)` = task criada + foto anexada (se houver) + planta anotada anexada. `computeStatus` define a vistoria como `finalizada` quando todos os defeitos estão completos; senão, `aberta`.
- **Envio ao ClickUp (`sendAll`)** é idempotente por etapas: cria a task (salva `task_id`/`task_url`), anexa a foto (`foto_ok`) e anexa a planta anotada gerada em canvas por `makePlantaAnotada` (`planta_ok`). Cada flag é persistida logo após a etapa, então reenviar retoma de onde parou. Erros de rede/5xx são tratados como "ambíguos" (a task pode ter sido criada) e 401 desconecta o ClickUp.
- **Imagens**: `compressImage`/`canvasToJpeg` reduzem qualidade e dimensão até caber no limite (planta: 2000px/8MB; foto: 1600px/700KB; planta anotada: 1600px/600KB). As imagens usam `crossOrigin='anonymous'` para o canvas não ficar "tainted" ao gerar a planta anotada.
- **Seleção da hierarquia do ClickUp**: workspace (team) → espaço (prefere o salvo em `vst_space` ou um cujo nome combine com "pós-obra") → pasta = **prédio** → lista = **unidade**. As tasks são criadas na lista (`v.list_id`).
- **Relatório** (`viewRelatorio`) é uma view otimizada para impressão (`@media print`, `.no-print`), com área de assinatura.

## Estilo

Tokens de cor em `:root`, com tema escuro via `prefers-color-scheme` e `[data-theme]`. Fontes: Space Grotesk (títulos), IBM Plex Sans/Mono. Layout mobile-first com `env(safe-area-inset-*)`. As prioridades (`Alta`/`Média`/`Baixa`) viram classes CSS `p-<prioridade>` e são mapeadas para a prioridade do ClickUp em `PRIO_NUM`.
