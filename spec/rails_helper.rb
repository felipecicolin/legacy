# frozen_string_literal: true

require "spec_helper"

if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"
  require "simplecov_json_formatter"

  SimpleCov.start "rails" do
    enable_coverage :branch

    # `:oneshot_line` responde "esta linha rodou?" em vez de "quantas vezes?".
    # É a única pergunta que um gate de 100% faz, e o modo custa bem menos: o
    # Ruby para de contar a linha depois do primeiro acerto. Habilitar
    # `:oneshot_line` desliga `:line` sozinho (são mutuamente exclusivos no
    # `Coverage.start`), e o `ResultAdapter` do simplecov reconstrói o array de
    # linhas no `.resultset.json` — `script/verify_coverage.rb` colaciona o
    # resultado sem saber a diferença. Branch coverage é ortogonal e continua
    # ligada, então o gate segue 100/100.
    enable_coverage :oneshot_line
    primary_coverage :oneshot_line

    formatter SimpleCov::Formatter::JSONFormatter
    if ENV["CI_NODE_INDEX"] || ENV["TEST_ENV_NUMBER"]
      test_env_number = ENV["TEST_ENV_NUMBER"]
      test_env_number = "0" if test_env_number.to_s.empty?

      command_name "ci-node-#{ENV['CI_NODE_INDEX'] || 'local'}-#{test_env_number}"
    else
      # `oneshot_line:` e não `line:` — com `:line` desligado em favor do
      # oneshot, o simplecov recusa um limiar sobre o critério desabilitado.
      # `script/verify_coverage.rb` continua cobrando `line:`, porque lá o que
      # se lê é o `.resultset.json`, onde o oneshot já virou array de linhas.
      minimum_coverage oneshot_line: 100.0, branch: 100.0
    end

    # Shim de ferramental para a CLI do i18n-tasks (carregado por
    # `bin/i18n-tasks`, exercitado ponta a ponta pelo passo `i18n-tasks health`
    # da CI). Vive fora da árvore de autoload do Rails e não é código de
    # aplicação.
    skip "lib/i18n_tasks/"
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

return unless Rails.env.test?

require "rspec/rails"
require "view_component/test_helpers"
require "webmock/rspec"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => error
  abort error.to_s.strip
end

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join("spec/fixtures"),
  ]

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ViewComponent::TestHelpers, type: :component
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
