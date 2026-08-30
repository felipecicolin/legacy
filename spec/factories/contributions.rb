# frozen_string_literal: true

FactoryBot.define do
  factory :contribution do
    campaign
    amount_cents { 25_000 }
    currency { "BRL" }
    origin { :one_off }
    status { :pending }
    contributor { association :profile }

    trait :confirmed do
      status { :confirmed }
      confirmed_at { Time.current }
      provider_reference { "SIM-contribution" }
    end

    trait :anonymous do
      anonymous { true }
    end
  end
end
