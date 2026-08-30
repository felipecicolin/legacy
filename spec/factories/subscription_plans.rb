# frozen_string_literal: true

FactoryBot.define do
  factory :subscription_plan do
    sequence(:key) { |n| "builder-#{n}" }
    amount_cents { 5_000 }
    currency { "BRL" }
    interval { :monthly }
    active { true }
  end
end
