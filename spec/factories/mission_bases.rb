# frozen_string_literal: true

FactoryBot.define do
  factory :mission_base do
    country
    sequence(:name) { |n| "Base Fictícia #{n}" }
    kind { :mission_base }
    sequence(:slug) { |n| "base-ficticia-#{n}" }
  end
end
