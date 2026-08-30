# frozen_string_literal: true

FactoryBot.define do
  factory :disbursement do
    ngo { association :ngo, :active }
    sequence(:reference) { |n| "REP-#{n}" }
    description { "Repasse para a base" }
    amount_cents { 18_400_00 }
    currency { "BRL" }
    scheduled_on { Date.current }
    status { :scheduled }

    trait :executed do
      status { :executed }
      executed_on { Date.current }
    end

    trait :for_campaign do
      campaign { association :campaign, ngo: ngo }
    end
  end
end
