# frozen_string_literal: true

FactoryBot.define do
  factory :project_photo do
    project
    taken_on { Date.current }

    after(:build) do |photo|
      photo.image.attach(GeotaggedPhoto.upload(filename: "obra.jpg"))
    end
  end
end
