# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    subscription_plan
    subscriber { association :profile }
    started_on { Date.current - 1.month }
    next_charge_on { Date.current }
    status { :active }

    trait :directed do
      campaign
    end
  end
end
