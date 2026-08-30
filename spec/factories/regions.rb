# frozen_string_literal: true

FactoryBot.define do
  factory :region do
    country
    sequence(:name) { |n| "Região #{n}" }
  end
end
