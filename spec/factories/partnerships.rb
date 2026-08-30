# frozen_string_literal: true

FactoryBot.define do
  factory :partnership do
    ngo
    owner { association :profile }
    kind { :financial }
    tier { :supporter }
    starts_on { Date.current }
    status { :active }
  end
end
