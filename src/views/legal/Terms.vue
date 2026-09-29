<script setup>
import LegalPage from './LegalPage.vue'
import { APP_NAME, APP_DOMAIN, LEGAL } from '@/config/brand'
</script>

<template>
  <LegalPage title="Termos de uso">
    <h2>1. Quem somos</h2>
    <p>
      O {{ APP_NAME }} ({{ APP_DOMAIN }}) é uma plataforma da <strong>{{ LEGAL.company }}</strong><template v-if="LEGAL.cnpj">,
      CNPJ {{ LEGAL.cnpj }}</template>, que permite a estabelecimentos e profissionais ("<strong>Estabelecimentos</strong>")
      criar uma página online ("<strong>Vitrine</strong>") para receber agendamentos, pedidos, reservas, pedidos de orçamento
      e inscrições dos seus próprios clientes ("<strong>Clientes finais</strong>").
    </p>

    <h2>2. Aceite</h2>
    <p>
      Ao criar uma conta ou usar a plataforma, você declara que leu e concorda com estes Termos e com a
      <RouterLink to="/privacidade">Política de privacidade</RouterLink>. Se não concordar, não utilize o serviço.
    </p>

    <h2>3. Cadastro do Estabelecimento</h2>
    <ul>
      <li>O cadastro passa por análise e pode ser aprovado ou recusado a nosso critério.</li>
      <li>O Estabelecimento é responsável pela veracidade dos dados informados e pela guarda da sua senha.</li>
      <li>Cada Estabelecimento responde pelo que publica na sua Vitrine: nome, logo, fotos, preços, textos e ofertas.</li>
      <li>É proibido usar a plataforma para atividades ilegais, conteúdo ofensivo, enganoso ou que viole direitos de terceiros.</li>
    </ul>

    <h2>4. Planos, pagamento e cancelamento</h2>
    <ul>
      <li>O uso é cobrado por assinatura mensal, conforme o plano escolhido e os valores informados no momento da contratação.</li>
      <li>Condições comerciais negociadas individualmente valem pelo prazo combinado. Depois disso, vale o preço de tabela.</li>
      <li>
        Ao valor da mensalidade é acrescida a taxa cobrada pela instituição de pagamento, que varia conforme a forma
        escolhida (cartão de crédito, PIX ou boleto). O valor total é informado antes de cada pagamento.
      </li>
      <li>Em caso de atraso no pagamento, o acesso ao painel e à Vitrine pode ser suspenso até a regularização.</li>
      <li>O Estabelecimento pode cancelar a qualquer momento. O cancelamento vale ao fim do período já pago, sem reembolso proporcional.</li>
      <li>Podemos alterar preços e planos com aviso prévio de pelo menos 30 dias.</li>
    </ul>

    <h2>5. Relação entre Estabelecimento e Cliente final</h2>
    <p>
      O {{ APP_NAME }} oferece a ferramenta. <strong>O serviço ou produto é prestado pelo Estabelecimento</strong>, que é o
      único responsável por atendimento, preços, qualidade, entregas, pagamentos combinados, trocas, cancelamentos e
      reembolsos junto aos seus Clientes finais. Não somos parte dessa relação de consumo.
    </p>

    <h2>6. Disponibilidade</h2>
    <p>
      Trabalhamos para manter a plataforma disponível, mas podem ocorrer interrupções para manutenção, falhas de
      terceiros (internet, hospedagem, e-mail, WhatsApp) ou casos fora do nosso controle. Lembretes e mensagens
      automáticas são um apoio e não substituem a confirmação direta com o cliente.
    </p>

    <h2>7. Propriedade intelectual</h2>
    <p>
      A marca {{ APP_NAME }}, o sistema e o layout da plataforma pertencem à {{ LEGAL.company }}. O conteúdo enviado pelo
      Estabelecimento (logo, fotos, textos) continua sendo dele, que nos autoriza a exibi-lo na sua Vitrine.
    </p>

    <h2>8. Limitação de responsabilidade</h2>
    <p>
      Na máxima extensão permitida pela lei, não respondemos por lucros cessantes, perda de clientes ou danos indiretos
      decorrentes do uso ou da indisponibilidade da plataforma. Nossa responsabilidade total fica limitada ao valor
      pago pelo Estabelecimento nos últimos 3 meses.
    </p>

    <h2>9. Suspensão e encerramento</h2>
    <p>
      Podemos suspender ou encerrar contas que violem estes Termos, a lei, ou que coloquem em risco a plataforma e
      outros usuários.
    </p>

    <h2>10. Alterações</h2>
    <p>Estes Termos podem ser atualizados. A versão vigente fica sempre nesta página, com a data da última atualização.</p>

    <h2>11. Contato e foro</h2>
    <p>
      Dúvidas: <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a>.
      <template v-if="LEGAL.city">Fica eleito o foro da comarca de {{ LEGAL.city }} para resolver questões relacionadas a estes Termos.</template>
    </p>
  </LegalPage>
</template>
