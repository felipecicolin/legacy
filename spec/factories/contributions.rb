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
      # Sequência, e não literal: a coluna tem índice único, e um valor fixo
      # fazia a SEGUNDA contribuição confirmada de qualquer exemplo reprovar —
      # com um erro sobre um campo que o exemplo nunca mencionou.
      sequence(:provider_reference) { |n| "SIM-contribution-#{n}" }
    end

    trait :anonymous do
      anonymous { true }
    end
  end
end
