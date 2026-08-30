# frozen_string_literal: true

FactoryBot.define do
  factory :event_registration do
    event
    profile
  end
end
