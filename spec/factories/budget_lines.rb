# frozen_string_literal: true

FactoryBot.define do
  factory :budget_line do
    budget
    category { :material }
    sequence(:description) { |n| "Material #{n}" }
    estimated_cents { 10_000 }
  end
end
