# frozen_string_literal: true

FactoryBot.define do
  factory :subscriber_benefit do
    subscription
    kind { :monthly_report }
    due_on { Date.current }
  end
end
