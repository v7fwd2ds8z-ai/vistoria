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

Qualquer pessoa pode pedir acesso pela tela de login: ela informa e-mail e nome, entra pelo link e fica numa tela de "aguardando aprovação". Quem é admin vê um contador de pedidos no topo do app e aprova ou recusa em **Acessos**. A tela da pessoa atualiza sozinha quando o pedido é aprovado.

As regras do banco garantem que só usuários aprovados leem ou alteram vistorias, defeitos e arquivos. Quem já tinha conta quando o recurso foi ativado continua aprovado.

### Ativar (uma vez)

A ordem importa: se o cadastro for aberto antes das regras novas, qualquer pessoa que criar conta vê os dados.

1. No **SQL Editor** do Supabase, rode [`supabase/aprovacao-de-acesso.sql`](supabase/aprovacao-de-acesso.sql), trocando `SEU-EMAIL@exemplo.com` no fim pelo e-mail de quem vai administrar.
2. Publique esta versão do `index.html`.
3. Em **Authentication → Sign In / Providers**, ative **Allow new users to sign up**.

Para tornar outra pessoa admin, rode `update public.usuarios set admin = true where email = '...';`.

## Rodar localmente

Não há build. Sirva a pasta com qualquer servidor estático, por exemplo:

```bash
python3 -m http.server 8000
```

e abra `http://localhost:8000`. Lembre de incluir essa URL nos *Redirect URLs* do Supabase para o link de login funcionar.
