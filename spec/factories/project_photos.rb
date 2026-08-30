# frozen_string_literal: true

FactoryBot.define do
  factory :project_photo do
    project
    taken_on { Date.current }
    photo_category { :during }

    # A foto real vem do `GeotaggedPhoto`, que a gera com GPS no EXIF: é a
    # mesma imagem que o `ExifScrubber` tem de limpar, e não uma fixture
    # binária que envelhece sem ninguém notar.
    image { GeotaggedPhoto.upload }
  end
end
