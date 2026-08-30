# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Legacy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks i18n_tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.load_path += Rails.root.glob("config/locales/**.{yml}")
    config.i18n.default_locale = "pt-BR"

    # A rails-i18n traz ~140 locales. Declarar o único que o produto fala faz o
    # backend descartar os outros já na carga, e faz `I18n.locale = :fr`
    # levantar em vez de trocar o idioma da tela em silêncio.
    config.i18n.available_locales = ["pt-BR"]
    config.time_zone = "Brasilia"

    # A aplicação é uma demo fechada e não deve ser indexada, mesmo que um
    # robô ignore o robots.txt.
    config.action_dispatch.default_headers["X-Robots-Tag"] = "noindex"
    config.exceptions_app = routes

    # NÃO coloque `app/components` em `config.assets.paths`. A receita corrente
    # para controllers Stimulus sidecar manda fazer isso, e o preço é alto: o
    # Propshaft trata TODO arquivo sob um asset path como asset, sem filtro de
    # extensão, então `bin/rails assets:precompile` copia
    # `app/components/*.rb` para `public/assets/` e ainda os lista no
    # `.manifest.json`, que é público. Verificado neste repo: as três classes
    # de componente apareceram em public/assets/ como
    # `button_component-<digest>.rb`.
    #
    # Por isso os controllers Stimulus de componente vivem junto com os demais,
    # em `app/javascript/controllers/<nome>_component_controller.js`. Perde-se
    # a colocação com a classe; ganha-se não publicar o código-fonte.

    # Os previews moram sob spec/ porque a suíte é RSpec e não existe test/.
    # A chave é `previews.paths` — no ViewComponent 4 o antigo `preview_paths`
    # não existe mais, e atribuir a ele não dá erro: só não faz nada, e a
    # listagem de previews abre vazia.
    config.view_component.previews.paths << Rails.root.join("spec/components/previews").to_s

    # Cada componente é dono da sua cópia, num YAML sidecar por locale. O
    # bin/i18n_sidecar_lint cobra a estrutura desses arquivos.
    config.view_component.generate.locale = true
    config.view_component.generate.distinct_locale_files = true

    # Os previews nativos do ViewComponent, em /rails/view_components. Sem
    # explorador de terceiros: é MVP, e a gem de UI a mais custa boot,
    # dependência e superfície. O layout é uma casca mínima, para o componente
    # aparecer sozinho em vez de dentro do chrome da aplicação.
    config.view_component.previews.default_layout = "component_preview"

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
