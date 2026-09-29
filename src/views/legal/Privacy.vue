<script setup>
import LegalPage from './LegalPage.vue'
import { APP_NAME, LEGAL } from '@/config/brand'
</script>

<template>
  <LegalPage title="Política de privacidade">
    <p>
      Esta política explica como o {{ APP_NAME }}, da <strong>{{ LEGAL.company }}</strong>, trata dados pessoais, de acordo
      com a Lei Geral de Proteção de Dados (Lei nº 13.709/2018, "LGPD").
    </p>

    <h2>1. Papéis de cada um</h2>
    <ul>
      <li>
        <strong>Dados dos Estabelecimentos</strong> (quem contrata a plataforma): somos os <strong>controladores</strong>.
      </li>
      <li>
        <strong>Dados dos Clientes finais</strong> (quem agenda, pede, reserva ou se inscreve numa Vitrine): o
        <strong>Estabelecimento é o controlador</strong> e nós atuamos como <strong>operadores</strong>, tratando os dados
        apenas para prestar o serviço contratado por ele.
      </li>
    </ul>

    <h2>2. Quais dados coletamos</h2>
    <ul>
      <li><strong>Estabelecimento:</strong> nome do responsável, e-mail, senha (guardada de forma criptografada), telefone, dados do negócio, logo, fotos e histórico de pagamentos.</li>
      <li><strong>Cliente final:</strong> nome, WhatsApp, e-mail (quando informado), endereço de entrega (em pedidos com entrega), e os detalhes do agendamento, pedido, reserva, orçamento ou inscrição.</li>
      <li><strong>Dados técnicos:</strong> registros de acesso exigidos pelo Marco Civil da Internet e informações básicas de navegação necessárias para o site funcionar.</li>
    </ul>

    <h2>3. Para que usamos</h2>
    <ul>
      <li>Criar e manter contas, Vitrines e o painel do Estabelecimento.</li>
      <li>Registrar agendamentos, pedidos, reservas, orçamentos e inscrições, e repassá-los ao Estabelecimento.</li>
      <li>Enviar confirmações, códigos de acesso e lembretes.</li>
      <li>Cobrar as assinaturas e cumprir obrigações legais e fiscais.</li>
      <li>Prevenir fraudes e manter a segurança da plataforma.</li>
    </ul>
    <p>Não vendemos dados pessoais e não os usamos para publicidade de terceiros.</p>

    <h2>4. Bases legais</h2>
    <p>
      Execução de contrato (prestar o serviço), cumprimento de obrigação legal, legítimo interesse (segurança e melhoria
      da plataforma) e, quando necessário, consentimento.
    </p>

    <h2>5. Com quem compartilhamos</h2>
    <ul>
      <li>Com o <strong>Estabelecimento</strong> escolhido pelo Cliente final, que recebe os dados do agendamento, pedido ou reserva.</li>
      <li>Com fornecedores que operam a plataforma: hospedagem e banco de dados (Supabase e Hostinger), envio de e-mails e processamento de pagamentos.</li>
      <li>Com autoridades, quando exigido por lei ou ordem judicial.</li>
    </ul>
    <p>Alguns fornecedores podem armazenar dados fora do Brasil, sempre com salvaguardas adequadas previstas na LGPD.</p>

    <h2>6. Por quanto tempo guardamos</h2>
    <p>
      Enquanto a conta do Estabelecimento estiver ativa e pelo tempo necessário para cumprir obrigações legais. Após o
      cancelamento, os dados são excluídos ou anonimizados em até 90 dias, salvo o que a lei exigir manter.
    </p>

    <h2>7. Segurança</h2>
    <p>
      Usamos conexão criptografada (HTTPS), senhas criptografadas e regras de acesso que impedem que um Estabelecimento
      veja dados de outro. Nenhum sistema é 100% invulnerável; em caso de incidente relevante, avisaremos os afetados e a
      ANPD, conforme a lei.
    </p>

    <h2>8. Seus direitos</h2>
    <p>
      Você pode pedir confirmação de tratamento, acesso, correção, anonimização, portabilidade, exclusão e informações
      sobre compartilhamento dos seus dados. <strong>Clientes finais</strong> devem falar primeiro com o Estabelecimento em
      que foram atendidos; nós o apoiamos no atendimento do pedido. Também é possível falar diretamente conosco.
    </p>

    <h2>9. Cookies e armazenamento local</h2>
    <p>
      Usamos apenas o necessário para o site funcionar, como manter você conectado e lembrar seu nome e endereço no
      próprio navegador para agilizar novos pedidos. Não usamos cookies de publicidade.
    </p>

    <h2>10. Contato do encarregado (DPO)</h2>
    <p>
      Para exercer seus direitos ou tirar dúvidas: <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a>.
    </p>
  </LegalPage>
</template>
