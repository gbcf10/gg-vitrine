# GG Agendaí

Plataforma de agendamento online multiempresa (barbearias, salões, estética, etc.) com assinatura mensal.

- **Frontend:** Vue 3 + Vite (site estático, hospedado na Hostnet)
- **Backend:** Supabase (PostgreSQL + Auth + Storage). As regras de negócio ficam no banco (RLS + funções RPC).

## Estrutura

```
supabase/migrations/0001_init.sql   Esquema completo: tabelas, RLS, planos, funções de agendamento e admin
public/.htaccess                     Regras do Apache (Hostnet) para as rotas do Vue funcionarem
src/
  config/brand.js                    Nome da plataforma, domínio, segmentos, nomes dos recursos
  lib/                               Supabase, sessão, formatação de datas/valores
  views/
    Landing.vue                      Página inicial com os planos
    auth/                            Login e cadastro de estabelecimento
    panel/                           Painel do estabelecimento (/painel)
    admin/                           Painel da plataforma (/admin)
    public/BookingPage.vue           Página de agendamento do cliente (/nome-do-negocio)
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
2. **SQL Editor** > cole todo o conteúdo de `supabase/migrations/0001_init.sql` > **Run**.
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

## Publicar na Hostnet

```bash
npm run build
```
Envie **o conteúdo** da pasta `dist/` (incluindo o `.htaccess`, que é um arquivo oculto) para a pasta pública do domínio (`public_html` ou `www`) pelo gerenciador de arquivos ou FTP da Hostnet.

- Ative o **SSL** do domínio no painel da Hostnet. O `.htaccess` já redireciona para HTTPS.
- A cada atualização, rode `npm run build` e envie o `dist/` de novo.

## Planos e limites

Definidos na tabela `plans` (dá para alterar direto no Supabase, sem mexer no código):

| Plano | Preço | Profissionais | Clientes |
|---|---|---|---|
| Básico | R$ 50 | 1 | 300 |
| Profissional | R$ 80 | 5 | ilimitado |
| Premium | R$ 120 | ilimitado | ilimitado |

Os limites são aplicados pelo banco, não só pela tela.

## Próximos passos

- [ ] Integração com gateway de pagamento (Asaas sugerido): Edge Function para criar a assinatura + webhook que ativa/marca atraso automaticamente
- [ ] Lembretes de agendamento (e-mail; depois WhatsApp)
- [ ] Relatórios (Profissional) e financeiro/dashboard (Premium)
- [ ] Acesso de funcionários ao painel (tabela `business_members` já suporta `staff`)
- [ ] Termos de uso e política de privacidade (LGPD)
