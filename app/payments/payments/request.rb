# frozen_string_literal: true

module Payments
  # O pedido inteiro num objeto só: valor em centavos, moeda e a referência do
  # que está sendo cobrado.
  #
  # Existe porque a mesma trinca atravessa a fachada, o provedor e a linha do
  # banco. Passá-la solta obrigaria cada método intermediário a repetir os três
  # parâmetros — e o limite de quatro do `Metrics/ParameterLists` acabaria na
  # primeira coisa que precisasse viajar junto.
  Request = Data.define(:amount_cents, :currency, :reference)
end
