# frozen_string_literal: true

module Payments
  # O que toda operação devolve, seja qual for o provedor.
  #
  # `status` é o vocabulário fechado de `PaymentProvider::STATUSES`, e o
  # construtor reprova o que não estiver nele: um provedor novo que invente
  # "approved" morre na fronteira, com o valor na mensagem, em vez de virar
  # linha inválida no banco.
  #
  # `reference` é a referência do provedor — o comprovante dele, não o nosso.
  # `failure_reason` é código, não frase: a mesma recusa aparece em tela, em
  # PDF e em relatório com palavras diferentes, e quem traduz é a view.
  Result = Data.define(:status, :reference, :processed_at, :failure_reason) do
    def initialize(status:, reference:, processed_at: nil, failure_reason: nil)
      raise ArgumentError, "unknown status #{status.inspect}" unless PaymentProvider::STATUSES.include?(status)

      super
    end
  end
end
