# Vistoria de entrega

App web de página única (`index.html`) para fazer a vistoria de entrega de unidades: você envia a planta, toca nela para marcar cada defeito (ambiente, prioridade, foto) e envia os pontos para o ClickUp.

## Como funciona

- **Login**: link mágico por e-mail (Supabase Auth). Só entram e-mails já cadastrados no projeto Supabase.
- **Dados**: vistorias e defeitos ficam nas tabelas `vistorias` e `defeitos` do Supabase; plantas e fotos ficam no bucket de Storage `vistoria-files`.
- **ClickUp**: os prédios e unidades vêm do ClickUp, acessado por um proxy (Cloudflare Worker) que cuida do OAuth.

## Configuração

No início do `<script>` em `index.html`, preencha:

| Variável            | O que é                                                        |
| ------------------- | -------------------------------------------------------------- |
| `SUPABASE_URL`      | URL do projeto Supabase (`https://<projeto>.supabase.co`)      |
| `SUPABASE_ANON_KEY` | Chave pública `anon` do projeto (Settings → API no Supabase)   |
| `API_BASE`          | URL do proxy do ClickUp (Worker)                               |
| `BUCKET`            | Nome do bucket de Storage (padrão: `vistoria-files`)           |

Use apenas a chave `anon` aqui — nunca a `service_role`, pois este arquivo é público.

## Dar acesso a alguém

Adicione o e-mail da pessoa em **Authentication → Users** no painel do Supabase. Sem isso, o login mostra "Esse e-mail ainda não tem acesso liberado".

## Rodar localmente

Não há build. Sirva a pasta com qualquer servidor estático, por exemplo:

```bash
python3 -m http.server 8000
```

e abra `http://localhost:8000`. Lembre de incluir essa URL nos *Redirect URLs* do Supabase para o link de login funcionar.
