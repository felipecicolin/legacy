# frozen_string_literal: true

# Espelha o .github/workflows/ci.yml para que dê para rodar a pipeline inteira
# antes de dar push. Rode com `bin/ci`.

CI.run do
  step "Setup: Ruby gems", "bundle check || bundle install"
  step "Setup: Node deps (regras customizadas do herb)", "npm ci || npm install"
  step "Setup: CSS", "bin/rails tailwindcss:build"
  step "Setup: Banco de teste", "env RAILS_ENV=test bin/rails db:drop db:create db:schema:load"

  step "Security: Brakeman", "bin/brakeman --no-pager --quiet"
  step "Security: Importmap audit", "bin/importmap audit"
  step "Security: Bundler audit", "bin/bundler-audit"

  step "Lint: RuboCop", "bin/rubocop --parallel"
  step "Lint: Reek (smells)", "bundle exec reek app/ lib/"
  step "Lint: Herb (templates HTML+ERB)", "bin/herb_lint"
  step "Lint: Stimulus controllers", "bin/stimulus_lint"

  step "i18n: Health (missing/unused/normalized)", "bin/i18n-tasks health"
  step "i18n: Disciplina de sidecar", "bin/i18n_sidecar_lint"

  step "Componentes: registry em dia", "bin/components_registry --check"

  step "Guard: nenhuma diretiva nova de supressão", "bin/directive_guard"

  step "DB: schema.rb em sincronia com as migrations",
       "env RAILS_ENV=test bin/rails db:abort_if_pending_migrations && " \
       "git diff --exit-code db/schema.rb"
  step "DB: Consistency (FKs, índices, NOT NULL)", "bundle exec database_consistency"

  step "Tests: preparo dos bancos paralelos",
       "env RAILS_ENV=test PARALLEL_TEST_PROCESSORS=2 bin/rails parallel:create parallel:load_schema"
  step "Tests: RSpec (paralelo)",
       "rm -rf coverage tmp/coverage && " \
       "env RAILS_ENV=test COVERAGE=1 bundle exec parallel_rspec spec/ -n 2"
  step "Tests: cobertura (colação + 100/100)", "ruby script/verify_coverage.rb"
end
