# frozen_string_literal: true

FactoryBot.define do
  factory :site_survey do
    project
    surveyed_by { association(:profile) }
    surveyed_on { Date.current }
  end
end
