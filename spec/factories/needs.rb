# frozen_string_literal: true

FactoryBot.define do
  factory :need do
    mission_base
    sequence(:title) { |n| "Telhas cerâmicas #{n}" }
    need_kind { :material }

    # A necessidade da BASE é o default, e não a da obra: é o caso que
    # justifica base e obra serem tabelas diferentes.
    trait :for_project do
      project { association :project, mission_base: mission_base }
    end

    trait :skilled do
      need_kind { :skill }
      skill
    end
  end
end
