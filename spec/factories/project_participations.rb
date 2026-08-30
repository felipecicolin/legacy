# frozen_string_literal: true

FactoryBot.define do
  factory :project_participation do
    project
    profile
    role { :volunteer }
    started_on { 1.month.ago.to_date }

    # `invited` é o default porque é assim que um convite nasce: vínculo que
    # concede alguma coisa é o caso especial.
    trait :active do
      status { :active }
    end

    trait :coordinator do
      active
      role { :coordinator }
    end
  end
end
