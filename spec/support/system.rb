# frozen_string_literal: true

# Chrome headless para os specs de sistema.
#
# `--disable-dev-shm-usage` porque o /dev/shm do runner do GitHub tem 64 MB e o
# Chrome estoura isso ao alocar o buffer da aba, morrendo com um
# "session deleted because of page crash" que não aponta para nada.
#
# `default_max_wait_time` sai do padrão do Capybara (2s) para 5s: o painel do
# administrador (#50) consulta bem mais coisa por página que qualquer tela
# anterior (alertas, quatro tiles, obras em andamento com foto, dois
# agregados, atividade recente), e o runner compartilhado do GitHub já é mais
# lento que uma máquina local — 2s bastava até aqui porque nenhuma tela pedia
# tanta consulta de uma vez.
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
      options.add_argument("--disable-dev-shm-usage")
    end
  end
end
