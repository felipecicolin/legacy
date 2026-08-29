# frozen_string_literal: true

FactoryBot.define do
  factory :organization do
    # Sequência no nome porque o slug sai dele: sem ela toda organização da
    # suíte disputaria o mesmo endereço, e o sufixo de desempate — que é
    # comportamento sob teste — correria em todo exemplo.
    sequence(:name) { |n| "Igreja da Paz #{n}" }
    organization_kind { :church }
  end
end
