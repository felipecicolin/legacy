# frozen_string_literal: true

FactoryBot.define do
  factory :project_phase do
    project
    sequence(:name) { |n| "Etapa #{n}" }
    weight { 1 }
    physical_progress { 50 }
    sequence(:position)
  end
end
