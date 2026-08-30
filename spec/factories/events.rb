# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "Evento de apoio #{n}" }
    kind { :talk }
    starts_at { 1.day.from_now }
    status { :published }
    ticket_price_cents { 0 }
    currency { "BRL" }

    trait :paid do
      ticket_price_cents { 2_500 }
    end
  end
end
