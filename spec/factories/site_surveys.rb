# frozen_string_literal: true

FactoryBot.define do
  factory :site_survey do
    project
    surveyed_by factory: :profile
    surveyed_on { Date.current }

    # `findings` só é exigido a partir de `submitted` — rascunho sem texto é
    # estado legítimo, e é por isso que quem submete traz a trait.
    trait :written do
      findings { "<div>Estrutura íntegra; telhado exige troca de 40 telhas.</div>" }
    end

    trait :submitted do
      written
      status { :submitted }
    end
  end
end
