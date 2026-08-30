# frozen_string_literal: true

FactoryBot.define do
  factory :candidacy do
    need
    profile

    # A candidatura de grupo é o outro lado do `CHECK`: quem traz o grupo tira
    # a pessoa, porque exatamente um dos dois vive preenchido.
    trait :from_a_group do
      profile { nil }
      volunteer_group { association :volunteer_group }
    end
  end

  factory :assignment do
    candidacy
    need { candidacy.need }
    starts_on { Date.current }
  end

  factory :need_fulfillment do
    need
    source factory: :assignment
    quantity { 1 }
    fulfilled_at { Time.current }
  end
end
