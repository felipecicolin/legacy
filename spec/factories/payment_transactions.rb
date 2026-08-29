# frozen_string_literal: true

FactoryBot.define do
  factory :payment_transaction do
    kind { :charge }
    status { :succeeded }
    amount_cents { 15_000 }
    currency { "BRL" }
    sequence(:reference) { |n| "doacao-#{n}" }
    provider_reference { "SIM-#{reference}" }
    processed_at { Time.current }
  end
end
