# frozen_string_literal: true

FactoryBot.define do
  factory :volunteer_engagement do
    profile
    engagement_model { :project_spot }
    engagement_area { :construction }
    started_on { 2.months.ago.to_date }

    # `volunteer_group { association ... }` e não `volunteer_group` pelado: o
    # FactoryBot resolve um nome pelado dentro de uma trait ANTES de considerar
    # associação, e o resultado é `nil` em silêncio — a trait aplica, o modelo
    # fica inválido, e o erro aponta para a validação em vez de para a fixture.
    #
    # Os nomes das traits também não repetem valor de enum (`corporate`,
    # `office`): o FactoryBot gera uma trait por valor, e a homônima colide.
    trait :in_a_group do
      engagement_model { :corporate }
      volunteer_group { association :volunteer_group }
    end

    trait :at_the_office do
      engagement_model { :office_fixed }
      engagement_area { :office }
    end
  end
end
