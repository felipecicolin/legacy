# frozen_string_literal: true

FactoryBot.define do
  factory :progress_report do
    project
    reported_by factory: :profile
    reported_on { Date.current }
    physical_progress { 30 }

    # `summary` só é exigido a partir de `submitted`, e é isso que faz o
    # rascunho sem texto ser um estado legítimo — quem submete traz a trait.
    trait :written do
      summary { "<div>Fundação concluída, alvenaria em andamento.</div>" }
    end

    trait :submitted do
      written
      status { :submitted }
    end

    trait :approved do
      written
      status { :approved }
      approved_by factory: :profile
      approved_at { Time.current }
    end
  end
end
