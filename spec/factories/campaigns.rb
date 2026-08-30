# frozen_string_literal: true

FactoryBot.define do
  factory :campaign do
    mission_base { association :mission_base, :active }
    sequence(:title) { |n| "Campanha da base #{n}" }
    goal_cents { 300_000 }
    starts_on { Date.current }
    status { :active }

    trait :closed do
      status { :closed }
    end

    trait :with_project do
      after(:build) do |campaign|
        campaign.project = build(:project, mission_base: campaign.mission_base)
      end
    end
  end
end
