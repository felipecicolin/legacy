# frozen_string_literal: true

FactoryBot.define do
  factory :volunteer_engagement do
    profile
    engagement_model { :project_spot }
    engagement_area { :construction }
    started_on { 2.months.ago.to_date }

    # Só o modelo corporativo exige grupo, e é ele que a trait monta.
    trait :corporate do
      engagement_model { :corporate }
      volunteer_group
    end

    trait :office do
      engagement_model { :office_fixed }
      engagement_area { :office }
    end
  end
end
