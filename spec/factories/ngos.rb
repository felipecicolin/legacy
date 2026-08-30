# frozen_string_literal: true

FactoryBot.define do
  factory :ngo do
    # Sequência no nome porque o slug sai dele: sem ela toda ONG da suíte
    # disputaria o mesmo endereço, e o sufixo de desempate — que é
    # comportamento sob teste — correria em todo exemplo.
    sequence(:name) { |n| "Igreja da Paz #{n}" }
    ngo_kind { :church }

    # `ngo_status` fica no default `pending`, que é como uma ONG nasce:
    # aparecer em busca é o caso especial, e ele pede a trait.
    trait :active do
      ngo_status { :active }
    end

    # Vitrine pública é PROMOÇÃO, não default: a ONG absorveu a sensibilidade do
    # lugar e nasce `restricted`. Abrir pede autor e justificativa, e a trait
    # existe para o exemplo que precisa da ONG já na vitrine.
    trait :listed do
      ngo_status { :active }

      after(:create) do |ngo|
        ngo.promote_visibility!(level: :public, author: create(:user),
                                justification: "Catálogo público")
      end
    end

    # País não é obrigatório desde a fusão — organização não tinha —, então a
    # trait existe para o exemplo que precisa do lugar.
    trait :in_country do
      country { association :country }
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
