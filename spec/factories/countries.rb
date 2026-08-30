# frozen_string_literal: true

FactoryBot.define do
  factory :country do
    # Faixa de uso privado do ISO 3166-1 (XA–XZ e XAA–XZZ): nenhum país real
    # aparece em fixture, e muito menos marcado como `high_risk`. A curadoria é
    # decisão editorial da equipe, e um teste que a simula com país de verdade
    # se lê como se a decisão já tivesse sido tomada.
    sequence(:iso_code) { |n| "X#{(65 + (n % 26)).chr}" }
    sequence(:iso3_code) { |n| "X#{(65 + (n / 26 % 26)).chr}#{(65 + (n % 26)).chr}" }
    currency_code { "USD" }
  end
end
