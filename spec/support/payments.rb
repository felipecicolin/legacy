# frozen_string_literal: true

# O provedor mora em `config.x`, que é estado do processo e sobrevive ao
# exemplo. Sem esta restauração, um spec que troca o provedor deixa o próximo
# rodando contra outro — e a ordem aleatória do RSpec faz isso reprovar de
# forma intermitente, no arquivo errado.
#
# `ensure` e não uma linha depois do `run`: um erro levantado fora do que o
# RSpec captura (um `before(:all)`, outro hook aninhado) pularia a restauração
# e deixaria o provedor trocado para o resto do processo.
RSpec.configure do |config|
  config.around do |example|
    original = Rails.application.config.x.payment_provider
    example.run
  ensure
    Rails.application.config.x.payment_provider = original
  end
end
