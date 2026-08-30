# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    ngo
    sequence(:title) { |n| "Reforma do telhado #{n}" }

    # `code` não entra: é coluna gerada pelo banco, e escrevê-la reprova no
    # Postgres. `status` fica em `surveying`, que é onde toda obra começa.
  end
end
