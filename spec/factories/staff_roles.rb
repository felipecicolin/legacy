# frozen_string_literal: true

FactoryBot.define do
  factory :staff_role do
    user
    staff_level { :support }

    # `admin` é o único nível que alcança `confidential`, então ele é o caso
    # especial e pede a trait — o padrão é o papel que enxerga menos.
    trait :admin do
      staff_level { :admin }
    end

    trait :curator do
      staff_level { :curator }
    end
  end
end
