# frozen_string_literal: true

FactoryBot.define do
  factory :skill do
    sequence(:key) do |number|
      entries = Vocabulary::Catalog.skills.entries
      entries.fetch((number - 1) % entries.size).fetch(:key)
    end
    category { "engineering" }
    sequence(:position)
  end
end
