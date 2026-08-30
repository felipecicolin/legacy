# frozen_string_literal: true

FactoryBot.define do
  factory :need do
    ngo
    sequence(:title) { |n| "Telhas cerâmicas #{n}" }
    need_kind { :material }

    # A necessidade da BASE é o default, e não a da obra: é o caso que
    # justifica base e obra serem tabelas diferentes.
    trait :for_project do
      project { association :project, ngo: ngo }
    end

    # `skill { association ... }` e não `skill` pelado: `skill` É um valor do
    # enum `need_kind`, e o FactoryBot gera uma trait com esse nome — o nome
    # pelado aplicava a trait homônima em vez de montar a associação, e o
    # `skill_id` ficava nulo em silêncio.
    trait :skilled do
      need_kind { :skill }
      skill { association :skill }
    end
  end
end
