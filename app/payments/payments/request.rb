# frozen_string_literal: true

module Payments
  # O pedido inteiro num objeto só: valor em centavos, moeda e a referência do
  # que está sendo cobrado.
  #
  # Existe porque a mesma trinca atravessa a fachada, o provedor e a linha do
  # banco. Passá-la solta obrigaria cada método intermediário a repetir os três
  # parâmetros — e o limite de quatro do `Metrics/ParameterLists` acabaria na
  # primeira coisa que precisasse viajar junto.
  #
  # Valida na construção, como o `Result`, e pelo mesmo motivo somado a um
  # segundo: o `Gateway` chama o provedor primeiro e grava o rastro depois. Um
  # pedido que só reprovasse no `create!` já teria atravessado o provedor — com
  # um gateway de verdade do outro lado, isso é dinheiro movido sem linha no
  # banco, que é justamente o que a fachada promete não deixar acontecer.
  #
  # `Integer` e não "numérico": centavo é contagem, e um `Float` aqui seria a
  # porta por onde o dinheiro em ponto flutuante entra.
  Request = Data.define(:amount_cents, :currency, :reference) do
    def initialize(amount_cents:, currency:, reference:)
      raise ArgumentError, "amount_cents must be a positive Integer, got #{amount_cents.inspect}" unless
        amount_cents.is_a?(Integer) && amount_cents.positive?
      raise ArgumentError, "currency must be an ISO 4217 code, got #{currency.inspect}" unless
        PaymentProvider::CURRENCY_FORMAT.match?(currency.to_s)
      raise ArgumentError, "reference must be present" if reference.blank?

      super
    end
  end
end
