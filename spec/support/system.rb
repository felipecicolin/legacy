# frozen_string_literal: true

# Chrome headless para os specs de sistema.
#
# `--disable-dev-shm-usage` porque o /dev/shm do runner do GitHub tem 64 MB e o
# Chrome estoura isso ao alocar o buffer da aba, morrendo com um
# "session deleted because of page crash" que não aponta para nada.
RSpec.configure do |config|
  config.before(type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
      options.add_argument("--disable-dev-shm-usage")
    end
  end
end
