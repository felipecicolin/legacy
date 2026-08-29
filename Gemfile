# frozen_string_literal: true

source "https://rubygems.org"

ruby "4.0.2"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Resolve conflitos entre classes do Tailwind na hora de compor (ApplicationComponent#class_merge)
gem "tailwind_merge"

# Componentes de view testáveis [https://viewcomponent.org]
gem "view_component"
# Renderiza SVG inline a partir do asset pipeline (IconComponent)
gem "inline_svg"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Traduções do próprio Rails para pt-BR: mensagem de validação, nome de mês,
# formato de moeda e de número, `distance_of_time_in_words`. Sem a gem esse
# miolo sai em inglês na tela, e nenhum dos três linters de i18n pega — eles
# cobram as NOSSAS chaves, não as do framework.
gem "rails-i18n"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"
# O `image_processing` 2.0 largou a dependência de ruby-vips e mandou o
# consumidor declará-la. Como o processador de variantes padrão do Active
# Storage é o vips, sem esta linha o `active_storage/transformers/vips` não
# carrega e a aplicação não sobe.
#
# Exige a libvips instalada na máquina (`brew install vips`, `apt install
# libvips`; o Dockerfile já a instala). O Active Storage tem um `rescue
# LoadError` que degradaria para um aviso, mas ele só reconhece a mensagem do
# dlopen — e o image_processing 2.0 a reescreve, então o rescue não pega e o
# boot morre. Sem rede de proteção: a libvips é requisito.
gem "ruby-vips", require: false

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Checks the schema against the models: missing FKs, indexes, NOT NULL, validations.
  gem "database_consistency", require: false

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  gem "factory_bot_rails"
  gem "faker"

  # HTML+ERB parser, formatter and linter [https://herb-tools.dev]
  gem "herb", require: false

  # Translation hygiene: missing / unused / unnormalized keys.
  gem "i18n-tasks", require: false

  # Git hooks manager — see lefthook.yml.
  gem "lefthook", require: false

  gem "parallel_tests"

  # Code smell detector [https://github.com/troessner/reek]
  gem "reek", require: false

  gem "rspec-rails"

  gem "rubocop", require: false
  gem "rubocop-capybara", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-i18n", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-thread_safety", require: false
  gem "rubocop-view_component", require: false

  gem "shoulda-matchers"
end

group :development do
  # N+1 query detector.
  gem "bullet"

  # Use console on exceptions pages
  gem "web-console"
end

group :test do
  # O `page` do ViewComponent::TestHelpers e os matchers `have_button`/
  # `have_link` são Capybara — sem a gem, specs de componente só têm o
  # `rendered_content` cru.
  gem "capybara"

  # Navegador de verdade para os specs de sistema. O spec dos tokens pergunta
  # ao `getComputedStyle` qual cor a utility resolveu: sem isso, um token
  # renomeado vira classe inexistente e some em silêncio — nenhum linter deste
  # repositório lê CSS. Chrome headless; o Selenium Manager resolve o driver.
  gem "selenium-webdriver"
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false
  gem "stackprof", require: false
  gem "test-prof", require: false
  gem "webmock"
end
