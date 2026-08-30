# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExifScrubber do
  let(:bytes) { GeotaggedPhoto.bytes }

  def scrub(attachable)
    described_class.call(attachable)
  end

  def scrubbed_bytes(attachable)
    scrub(attachable).fetch(:io).read
  end

  it "starts from a photo that really carries GPS" do
    expect(GeotaggedPhoto.exif_fields(bytes)).to include("exif-ifd3-GPSLatitude")
  end

  describe "what it destroys" do
    it "leaves no EXIF field at all in the produced bytes" do
      expect(GeotaggedPhoto.exif_fields(scrubbed_bytes(GeotaggedPhoto.upload))).to be_empty
    end

    # A pergunta do arquivo, e não a da biblioteca: o bloco de metadados saiu
    # dos bytes, em vez de a libvips ter deixado de interpretá-lo.
    it "leaves no metadata marker in the raw bytes" do
      expect(scrubbed_bytes(GeotaggedPhoto.upload)).not_to include(GeotaggedPhoto::MARKER)
    end

    it "keeps the image itself readable" do
      image = Vips::Image.new_from_buffer(scrubbed_bytes(GeotaggedPhoto.upload), "")

      expect([image.width, image.height]).to eq([64, 48])
    end

    # A tag de orientação mora no bloco de EXIF e some com ele. Sem mais nada,
    # todo retrato de celular sairia deitado — um bug em cem por cento das
    # fotos tiradas em pé, que ninguém associaria à remoção de metadado. Quem
    # salva é o `autorot` do `ImageProcessing`, que gira os PIXELS antes de a
    # tag sumir. É propriedade da biblioteca, não deste código, e por isso está
    # cobrada aqui: passar `autorot: false` ou trocar por um `write_to_file`
    # direto desliga a correção sem levantar erro nenhum.
    it "rotates the pixels before the orientation tag disappears" do
      upload = GeotaggedPhoto.upload(data: GeotaggedPhoto.sideways_bytes)
      image = Vips::Image.new_from_buffer(scrubbed_bytes(upload), "")

      expect([image.width, image.height]).to eq([48, 64])
    end
  end

  describe "the shapes it accepts" do
    it "keeps the filename and the content type of an uploaded file" do
      expect(scrub(GeotaggedPhoto.upload(filename: "base.jpg")))
        .to include(filename: "base.jpg", content_type: "image/jpeg")
    end

    it "accepts the io/filename hash Active Storage documents" do
      scrubbed = scrub(io: StringIO.new(bytes), filename: "base.jpg", content_type: "image/jpeg")

      expect(GeotaggedPhoto.exif_fields(scrubbed.fetch(:io).read)).to be_empty
    end

    it "accepts a path, taking the filename from it" do
      path = Rails.root.join("tmp/geotagged.jpg")
      path.binwrite(bytes)

      expect(scrub(path)).to include(filename: "geotagged.jpg")
    end

    # Sem content_type declarado o hash sai sem a chave, e o Active Storage
    # identifica o tipo sozinho — melhor que gravar um palpite errado.
    it "omits the content type when the source does not declare one" do
      path = Rails.root.join("tmp/geotagged.jpg")
      path.binwrite(bytes)

      expect(scrub(path)).not_to have_key(:content_type)
    end

    it "names the file jpg when the source has no extension to go by" do
      scrubbed = scrub(io: StringIO.new(bytes), filename: "base", content_type: "image/jpeg")

      expect(Vips::Image.new_from_buffer(scrubbed.fetch(:io).read, "").width).to eq(64)
    end
  end

  describe "the shapes it refuses" do
    it "passes nil through, because that is how an attachment is removed" do
      expect(scrub(nil)).to be_nil
    end

    it "passes the empty string through for the same reason" do
      expect(scrub("")).to eq("")
    end

    it "refuses a blob, whose bytes are already stored" do
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: "base.jpg")

      expect { scrub(blob) }.to raise_error(described_class::AlreadyStored)
    end

    it "refuses a signed id, which is a blob by another name" do
      expect { scrub("Zm9v--deadbeef") }.to raise_error(described_class::AlreadyStored)
    end

    it "refuses something that is not a file at all" do
      expect { scrub(42) }.to raise_error(described_class::Unsupported)
    end

    it "refuses bytes that libvips cannot open as an image" do
      not_an_image = { io: StringIO.new("nem de longe um jpeg"), filename: "base.jpg" }

      expect { scrub(not_an_image) }.to raise_error(described_class::Unsupported)
    end
  end
end
