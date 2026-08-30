# frozen_string_literal: true

FactoryBot.define do
  factory :volunteer_group do
    ngo
    coordinator factory: :profile
    sequence(:name) { |n| "Turma da Construtora #{n}" }

    # Sem trait `:available` própria: `available` é valor do enum `group_status`
    # e o FactoryBot já gera a trait homônima, que faz exatamente isto.
    trait :ready do
      group_status { :available }
    end
  end
end
