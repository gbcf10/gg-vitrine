# GG Vitrine

Plataforma multiempresa com assinatura mensal. Cada negócio ganha uma **vitrine** com link próprio (`ggvitrine.com.br/nome-do-negocio`), com um destes tipos:

| Tipo | Para quem | O cliente... |
|---|---|---|
| **Agendamento** | Barbearia, clínica, quadra, aulas, pet... | marca horário |
| **Catálogo e pedidos** | Lanchonete, doces, loja, açaí... | monta o pedido (chega no WhatsApp e fica salvo no painel) |
| **Orçamentos** | Eletricista, pintor, montador... | pede orçamento |
| **Reservas** | Restaurante (mesa), chalé (diárias), aluguel | pede reserva, que o dono confirma |
| **Eventos e turmas** | Workshops, cursos, aulas coletivas | se inscreve (com limite de vagas) |
| **Cartão digital** | Autônomos em geral | vê contatos, redes, fotos e avaliações |

Extras (conforme o plano): links, galeria, avaliações moderadas, cartão fidelidade, cupons, QR Code/cartaz e lembrete pelo WhatsApp.

- **Frontend:** Vue 3 + Vite (site estático, hospedado na Hostinger)
- **Backend:** Supabase (PostgreSQL + Auth + Storage). As regras de negócio ficam no banco (RLS + funções RPC).

## Estrutura

```
supabase/migrations/                 Banco: rodar os arquivos em ordem (0001, 0002, 0003...)
public/.htaccess                     Regras do servidor (Hostinger) para as rotas do Vue funcionarem
scripts/deploy-hostinger.mjs         Publicação: npm run deploy
supabase/scripts/                    Scripts avulsos (ex.: apagar dados de teste)
src/
  config/brand.js                    Nome da plataforma, domínio, segmentos, nomes dos recursos
  lib/                               Supabase, sessão, formatação de datas/valores
  views/
    Landing.vue                      Página inicial com os planos
    auth/                            Login e cadastro de estabelecimento
    panel/                           Painel do estabelecimento (/painel)
    admin/                           Painel da plataforma (/admin)
    public/PublicPage.vue            Vitrine pública (/nome-do-negocio)
  components/public/                 Blocos de cada tipo de vitrine e extras (galeria, avaliações...)
```

## Como funciona o fluxo

1. O profissional se cadastra em `/cadastro`, e o estabelecimento fica **em análise**.
2. Em `/admin/empresas`, você **aprova** ou **recusa** o cadastro.
3. O dono escolhe o plano em `/painel/assinatura`. A assinatura fica **aguardando pagamento**.
4. Você registra o pagamento no admin (por enquanto manual, via PIX). A assinatura fica **ativa** e o painel é liberado.
5. O dono cadastra serviços, profissionais e horários e divulga o link `seudominio.com/nome-do-negocio`.
6. O cliente escolhe serviço, profissional, data e horário e confirma com um código enviado ao e-mail. Depois pode ver, cancelar ou remarcar em "Meus agendamentos".

**Preço negociado:** em `/admin/empresas` > *Plano/preço*, você define um preço personalizado e/ou um desconto permanente, por X meses ou até uma data. Quando o prazo acaba, a cobrança volta sozinha ao valor cheio.

**Bloquear inadimplente:** *Bloquear* em `/admin/empresas`. O painel e a página pública saem do ar na hora.

## Configuração (uma vez só)

### 1. Supabase
1. Crie um projeto em https://supabase.com (região São Paulo).
2. **SQL Editor** > cole e rode, **nesta ordem**, cada arquivo de `supabase/migrations/`: `0001_init.sql`, `0002_cardapio.sql`, `0003_vitrines.sql`, `0004_lembretes.sql`.
3. **Authentication > URL Configuration**:
   - *Site URL*: `https://seudominio.com.br`
   - *Redirect URLs*: `https://seudominio.com.br/**` e `http://localhost:5173/**`
4. **Authentication > Email Templates > Magic Link**: inclua o código para o cliente final, por exemplo:
   `<p>Seu código de acesso: <strong>{{ .Token }}</strong></p>`
5. Para produção, configure um SMTP próprio em **Authentication > SMTP Settings**. O e-mail padrão do Supabase tem limite baixo de envios por hora.

### 2. Projeto local
```bash
npm install
cp .env.example .env     # preencha com a URL e a chave anon (Project Settings > API)
npm run dev              # http://localhost:5173
```

### 3. Tornar-se administrador
Crie sua conta pelo site e rode no SQL Editor:
```sql
insert into platform_admins (user_id)
select id from auth.users where email = 'seu-email@exemplo.com';
```

## Publicar na Hostinger

### Primeira vez
1. **Domínio:** registre `ggvitrine.com.br` (Hostinger ou Registro.br) e aponte para a hospedagem.
2. **hPanel > Sites:** adicione o site `ggvitrine.com.br`.
3. **hPanel > Segurança > SSL:** ative o SSL grátis. O `.htaccess` já redireciona tudo para HTTPS.
4. **hPanel > Avançado > Acesso SSH:** ative o SSH e anote IP, usuário e porta (normalmente 65002).
5. Crie o arquivo `.env.deploy` na raiz do projeto (não vai para o git):
   ```
   HOSTINGER_HOST=IP_DO_SERVIDOR
   HOSTINGER_USER=u123456789
   HOSTINGER_PORT=65002
   HOSTINGER_PATH=domains/ggvitrine.com.br/public_html
   ```
6. **Supabase > Authentication > URL Configuration:** troque o *Site URL* para `https://ggvitrine.com.br` e adicione `https://ggvitrine.com.br/**` nas *Redirect URLs*.

### A cada atualização
```bash
npm run deploy
```
Gera o build e envia a pasta `dist/` (com o `.htaccess`) por SSH. Sem SSH, dá para enviar o conteúdo de `dist/` pelo **Gerenciador de arquivos** do hPanel para `public_html`.

## E-mails com o domínio (Resend)

Usado para: confirmação de cadastro, código de acesso do cliente e lembretes automáticos.

1. Crie uma conta em https://resend.com e adicione o domínio `ggvitrine.com.br`. Copie os registros DNS que o Resend mostrar para **hPanel > Domínios > DNS**.
2. Gere uma **API Key** no Resend.
3. **Supabase > Authentication > SMTP Settings:** ative o SMTP próprio com
   host `smtp.resend.com`, porta `465`, usuário `resend`, senha = a API Key, remetente `nao-responda@ggvitrine.com.br`.
4. **Lembretes automáticos:** rode no SQL Editor
   ```sql
   select vault.create_secret('re_SUA_CHAVE', 'resend_api_key');
   select vault.create_secret('GG Vitrine <lembretes@ggvitrine.com.br>', 'reminder_from_email');
   ```
   A partir daí, o banco envia os lembretes a cada 5 minutos (histórico em **Painel > Lembretes**).

## Antes de lançar
- [ ] Preencher CNPJ, e-mail de contato e cidade do foro em `src/config/brand.js` (`LEGAL`) e revisar Termos e Privacidade
- [ ] Preencher o WhatsApp de suporte em `src/config/brand.js` (`SUPPORT_WHATSAPP`)
- [ ] Configurar os e-mails com o domínio (seção acima)
- [ ] Apagar as vitrines de teste com `supabase/scripts/limpar-dados-de-teste.sql`
- [ ] Religar **Confirm email** em Authentication > Providers > Email

## Planos e limites

Definidos na tabela `plans` (dá para alterar direto no Supabase, sem mexer no código):

| Plano | Preço | Profissionais | Clientes |
|---|---|---|---|
| Básico | R$ 50 | 1 | 300 |
| Profissional | R$ 80 | 5 | ilimitado |
| Premium | R$ 120 | ilimitado | ilimitado |
| Catálogo e pedidos | R$ 60 | — | ilimitado |
| Reservas | R$ 60 | — | — |
| Eventos e turmas | R$ 50 | — | — |
| Orçamentos | R$ 40 | — | — |
| Cartão digital | R$ 25 | — | — |

Os limites são aplicados pelo banco, não só pela tela.

## Próximos passos

- [ ] Integração com gateway de pagamento (Asaas sugerido): Edge Function para criar a assinatura + webhook que ativa/marca atraso automaticamente
- [ ] Lembretes automáticos por WhatsApp (API paga). Por e-mail já estão prontos.
- [ ] Pagamento online / sinal com split (porcentagem da plataforma)
- [ ] Relatórios (Profissional) e financeiro/dashboard (Premium)
- [ ] Acesso de funcionários ao painel (tabela `business_members` já suporta `staff`)
