# frozen_string_literal: true

FactoryBot.define do
  factory :receipt do
    contribution { association :contribution, :confirmed }
  end
end
