# frozen_string_literal: true

FactoryBot.define do
  factory :volunteer_group do
    organization
    coordinator factory: :profile
    sequence(:name) { |n| "Turma da Construtora #{n}" }

    trait :available do
      group_status { :available }
    end
  end
end
