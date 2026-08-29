# frozen_string_literal: true

# O contador do `rate_limit` vive num MemoryStore (ver config/environments/
# test.rb) que sobrevive ao exemplo. Sem esta limpeza, o spec que gasta as dez
# tentativas deixa o contador cheio para quem rodar depois no mesmo processo —
# e a ordem aleatória do RSpec faz isso reprovar de forma intermitente, no
# arquivo errado.
RSpec.configure do |config|
  config.before { ActionController::Base.cache_store.clear }
end
