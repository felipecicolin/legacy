# frozen_string_literal: true

FactoryBot.define do
  factory :expense do
    project
    recorded_by { association :profile }
    amount_cents { 1_000 }
    currency { "BRL" }
    incurred_on { Date.current }
    category { :material }
    status { :recorded }
  end
end
