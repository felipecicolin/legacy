# frozen_string_literal: true

FactoryBot.define do
  factory :project_participation do
    project
    profile
    role { :volunteer }
    started_on { Date.current }
  end
end
