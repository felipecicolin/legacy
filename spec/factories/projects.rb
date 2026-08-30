# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    mission_base
    title { "Reforma da sala comunitária" }
    funding_target_cents { 300_000 }
  end
end
