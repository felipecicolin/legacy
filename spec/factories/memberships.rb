# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    profile
    organization
    role { :member }

    # `accepted_at` fica nulo por padrão porque é assim que um convite nasce.
    # Vínculo que concede permissão é o caso especial, e pede a trait.
    trait :accepted do
      accepted_at { Time.current }
    end
  end
end
