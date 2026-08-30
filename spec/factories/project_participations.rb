# frozen_string_literal: true

FactoryBot.define do
  factory :project_participation do
    project
    profile
    participation_role { :volunteer }
    started_on { 1.month.ago.to_date }

    # `invited` é o default porque é assim que um convite nasce: vínculo que
    # concede alguma coisa é o caso especial.
    trait :active do
      participation_status { :active }
    end

    trait :coordinator do
      active
      participation_role { :coordinator }
    end
  end
end
