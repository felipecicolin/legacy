# frozen_string_literal: true

FactoryBot.define do
  factory :budget do
    project
    currency { "BRL" }
    status { :draft }
  end
end
