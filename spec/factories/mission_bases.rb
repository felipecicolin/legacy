# frozen_string_literal: true

FactoryBot.define do
  factory :mission_base do
    country
    sequence(:name) { |n| "Base do Vale #{n}" }
    base_kind { :mission_base }

    # `base_status` fica no default `pending`, que é como uma base nasce:
    # aparecer em busca é o caso especial, e ele pede a trait.
    trait :active do
      base_status { :active }
    end

    # Coordenada é o dado que `confidential` recusa — a trait existe para os
    # exemplos que exercitam justamente essa recusa.
    trait :located do
      address { "Rua das Palmeiras, 120" }
      latitude { -23.55052 }
      longitude { -46.633308 }
    end
  end
end
