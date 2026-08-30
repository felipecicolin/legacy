# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectPhoto do
  let(:project) { create(:project) }

  describe "the EXIF that never reaches the storage" do
    # O que se inspeciona é o BLOB ARMAZENADO, e não o objeto do anexo: é o
    # arquivo que viaja em print e em e-mail encaminhado.
    it "destroys the metadata block on ingestion" do
      photo = create(:project_photo, project: project)

      expect(photo.image.blob.download).not_to include(GeotaggedPhoto::MARKER)
    end

    it "leaves no exif field behind" do
      photo = create(:project_photo, project: project)

      expect(GeotaggedPhoto.exif_fields(photo.image.blob.download)).to be_empty
    end
  end

  describe "what the server refuses" do
    def photo_with(io, content_type:, filename: "obra.jpg")
      upload = Rack::Test::UploadedFile.new(io, content_type, original_filename: filename)
      build(:project_photo, project: project, image: upload)
    end

    # O content-type declarado vem do cliente. Quem responde de verdade é a
    # libvips não conseguir abrir os bytes — o `ExifScrubber` levanta, e o
    # writer traduz isso em erro de campo em vez de 500.
    it "refuses a file with no picture inside, however it calls itself" do
      forged = photo_with(StringIO.new("isto nao e uma imagem"), content_type: "image/jpeg")

      expect(forged).not_to be_valid
    end

    # A propriedade que importa não é a mensagem: é que os bytes recusados
    # nunca chegaram ao serviço de storage.
    it "stores nothing at all when the bytes are refused" do
      forged = photo_with(StringIO.new("isto nao e uma imagem"), content_type: "image/jpeg")

      expect(forged.image).not_to be_attached
    end

    it "refuses a content type outside the whitelist" do
      expect(photo_with(StringIO.new("%PDF-1.7"), content_type: "application/pdf")).not_to be_valid
    end

    it "refuses a file above the size limit" do
      heavy = photo_with(StringIO.new("x" * (described_class::MAX_BYTE_SIZE + 1)), content_type: "image/jpeg")

      expect(heavy.tap(&:valid?).errors[:image].join).to include("12 MB")
    end

    it "refuses a record with no picture at all" do
      expect(build(:project_photo, project: project, image: nil)).not_to be_valid
    end
  end

  describe "the variants the gallery asks for" do
    # As três larguras são as do `ImageFrameComponent`, e é ele quem monta o
    # `srcset`. O que este exemplo cobra é que a variante SAI — sem libvips a
    # aplicação nem sobe, e com ela um formato errado levantaria aqui.
    it "processes every width the image frame declares" do
      photo = create(:project_photo, project: project)
      widths = ImageFrameComponent::WIDTHS.map do |width|
        photo.image.variant(resize_to_limit: [width, nil]).processed.key.present?
      end

      expect(widths).to all(be(true))
    end
  end

  describe "#credit_for" do
    let(:photographer) { create(:profile, legal_name: "Ana Ribeiro", display_name: "Ana R.") }

    it "names the photographer when the reader reaches the project" do
      photo = create(:project_photo, project: project, taken_by: photographer)

      expect(photo.credit_for(Visibility::Context.new(clearance: :confidential))).to eq("Ana R.")
    end

    # A obra está protegida, mas a legenda contaria quem esteve lá.
    it "omits the photographer when the reader does not reach the project" do
      photo = create(:project_photo, project: project, taken_by: photographer)

      expect(photo.credit_for(Visibility::Context.anonymous)).to be_nil
    end

    it "omits a credit that was never recorded" do
      photo = create(:project_photo, project: project, taken_by: nil)

      expect(photo.credit_for(Visibility::Context.new(clearance: :confidential))).to be_nil
    end
  end

  # Foto avulsa da obra existe: nem toda foto acompanha relatório.
  it "accepts a photo with no progress report" do
    expect(build(:project_photo, project: project, progress_report: nil)).to be_valid
  end

  it "refuses a photo dated in the future" do
    expect(build(:project_photo, project: project, taken_on: Date.current.tomorrow)).not_to be_valid
  end

  it "labels the category in pt-BR" do
    expect(build(:project_photo, project: project, category: :before).category_label).to eq("Antes")
  end

  it "orders by category and position" do
    last = create(:project_photo, project: project, category: :after, position: 0)
    first = create(:project_photo, project: project, category: :before, position: 1)

    expect(project.project_photos.ordered).to eq([first, last])
  end
end
