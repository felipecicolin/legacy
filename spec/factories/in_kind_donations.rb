# frozen_string_literal: true

FactoryBot.define do
  factory :in_kind_donation do
    donor { association :organization }
    category { :material }
    sequence(:title) { |n| "Material doado #{n}" }
    quantity { 1 }
    estimated_value_cents { 2_000 }
    status { :offered }
  end
end
