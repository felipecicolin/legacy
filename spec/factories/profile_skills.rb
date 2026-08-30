# frozen_string_literal: true

FactoryBot.define do
  factory :profile_skill do
    profile
    skill
    proficiency { :intermediate }
    years_of_experience { 3 }
  end
end
