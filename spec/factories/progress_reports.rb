# frozen_string_literal: true

FactoryBot.define do
  factory :progress_report do
    project
    reported_by { association(:profile) }
    reported_on { Date.current }
    physical_progress { 50 }
  end
end
