# frozen_string_literal: true

FactoryBot.define do
  factory :credential do
    profile
    kind { :crea }
    sequence(:number) { |n| "CREA-SP-#{n}" }
    issuing_body { "CREA-SP" }
    expires_on { 1.year.from_now.to_date }
  end
end
