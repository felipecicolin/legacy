# frozen_string_literal: true

# O provedor mora em `config.x`, que é estado do processo e sobrevive ao
# exemplo. Sem esta restauração, um spec que troca o provedor deixa o próximo
# rodando contra outro — e a ordem aleatória do RSpec faz isso reprovar de
# forma intermitente, no arquivo errado.
RSpec.configure do |config|
  config.around do |example|
    original = Rails.application.config.x.payment_provider
    example.run
    Rails.application.config.x.payment_provider = original
  end
end
