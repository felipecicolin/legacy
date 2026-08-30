# frozen_string_literal: true

FactoryBot.define do
  factory :deployment do
    mission_base
    sequence(:name) { |n| "Envio de campo #{n}" }
    departs_on { 1.month.from_now.to_date }
    returns_on { 6.weeks.from_now.to_date }
  end

  factory :deployment_member do
    deployment
    profile
    member_role { :volunteer }
  end
end
