# frozen_string_literal: true

module Payments
  # O contrato. Todo provedor cumpre estas quatro perguntas — o simulado de
  # hoje e o gateway de verdade de amanhã.
  #
  # É módulo, e não um documento em `docs/`, porque assim a implementação que
  # esquecer uma operação morre com o nome da classe na mensagem, em vez de
  # estourar um `NoMethodError` anônimo três camadas acima.
  #
  # As três operações recebem um `Request` e devolvem um `Result` — valor,
  # moeda, referência de um lado; situação, comprovante, horário e motivo do
  # outro. Nenhuma delas recebe instrumento de pagamento: o que o provedor
  # precisa para cobrar é problema do provedor, e nesta demo não existe
  # provedor de verdade, então também não existe o dado.
  module PaymentProvider
    # Os dois vocabulários fechados do domínio de pagamento, no contrato e não
    # espalhados: `payment_transactions` deriva os dois enums daqui, e o
    # `Result` valida o status contra esta lista. Uma operação nova ou uma
    # situação nova entra num lugar só.
    OPERATIONS = %i[charge refund schedule_recurring].freeze

    # `pending` existe para o meio de pagamento que não responde na hora — o
    # boleto e o PIX agendado do mundo real. Sem ele a UI só saberia tratar sim
    # e não, e a primeira integração de verdade encontraria uma terceira
    # resposta que ninguém desenhou.
    STATUSES = %i[succeeded pending failed refused].freeze

    # Sem padrão de propósito. O padrão errado tem dois lados ruins: `false`
    # esconde a marca de simulação numa demo, `true` marca dinheiro real como
    # de mentira. Quem implementa responde — e o `NotImplementedError` cobra.
    def simulated?
      raise NotImplementedError, "#{self.class} must implement #simulated?"
    end

    def charge(_request)
      raise NotImplementedError, "#{self.class} must implement #charge"
    end

    def refund(_request)
      raise NotImplementedError, "#{self.class} must implement #refund"
    end

    def schedule_recurring(_request)
      raise NotImplementedError, "#{self.class} must implement #schedule_recurring"
    end
  end
end
