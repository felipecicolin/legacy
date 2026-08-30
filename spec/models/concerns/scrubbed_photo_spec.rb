# frozen_string_literal: true

require "rails_helper"

# O host é o `SensitiveTestRecord` de `spec/support/`, pelo mesmo motivo do
# spec de `Sensitive`: os modelos de obra vêm em issues próprias.
RSpec.describe ScrubbedPhoto do
  let(:record) { SensitiveTestRecord.create!(name: "Base do Vale") }

  # A pergunta que a issue faz é sobre o ARQUIVO, não sobre o anexo: `download`
  # lê de volta o que o serviço de storage guardou.
  def stored_bytes = record.photo.blob.download

  describe "the writer door" do
    before { record.update!(photo: GeotaggedPhoto.upload) }

    it "stores a file with no EXIF field left" do
      expect(GeotaggedPhoto.exif_fields(stored_bytes)).to be_empty
    end

    it "stores a file with no metadata marker in its raw bytes" do
      expect(stored_bytes).not_to include(GeotaggedPhoto::MARKER)
    end
  end

  # `Attached::One#attach` delega ao writer, então a mesma limpeza vale — e é
  # este exemplo que prova que a porta é uma só.
  describe "the attach door" do
    before { record.photo.attach(GeotaggedPhoto.upload) }

    it "stores a file with no EXIF field left" do
      expect(GeotaggedPhoto.exif_fields(stored_bytes)).to be_empty
    end
  end

  it "still removes an attachment when assigned nil" do
    record.update!(photo: GeotaggedPhoto.upload)
    record.update!(photo: nil)

    expect(record.reload.photo).not_to be_attached
  end

  # O limite da defesa, escrito como exemplo para não virar promessa: um blob
  # pronto (o que o direct upload devolve) não tem como ser limpo na ingestão,
  # porque a ingestão dele já aconteceu em outro lugar.
  it "refuses a blob that was uploaded somewhere else" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(GeotaggedPhoto.bytes),
                                                  filename: "base.jpg")

    expect { record.photo.attach(blob) }.to raise_error(ExifScrubber::AlreadyStored)
  end
end
