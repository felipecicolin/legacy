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

  # A porta de COLEÇÃO. Semântica diferente da singular de propósito: no
  # singular o campo É uma foto e o que não abre como imagem é recusado; aqui
  # o campo é documentação de obra, com planta em PDF e foto no meio.
  describe ".attaches_scrubbed_files" do
    let(:need) { create(:need) }

    def pdf(text = "%PDF-1.7 laudo")
      Rack::Test::UploadedFile.new(StringIO.new(text), "application/pdf", original_filename: "laudo.pdf")
    end

    # O buraco que este arquivo existe para fechar: `has_many_attached` cru não
    # passava pelo scrubber, e a descrição do campo diz "planta, FOTO,
    # especificação".
    it "destroys the metadata of a picture in the collection" do
      need.references.attach(GeotaggedPhoto.upload)

      expect(need.reload.references.first.blob.download).not_to include(GeotaggedPhoto::MARKER)
    end

    it "leaves no exif field behind" do
      need.references.attach(GeotaggedPhoto.upload)

      expect(GeotaggedPhoto.exif_fields(need.reload.references.first.blob.download)).to be_empty
    end

    # Recusar o PDF quebraria a funcionalidade: laudo e planta são o conteúdo
    # principal deste campo.
    it "passes a file that is not a picture through untouched" do
      need.references.attach(pdf("%PDF-1.7 laudo do engenheiro"))

      expect(need.reload.references.first.blob.download).to eq("%PDF-1.7 laudo do engenheiro")
    end

    # O IO é consumido pelo scrubber antes de ele descobrir que não abre o
    # arquivo. Sem rebobinar, o que chega ao storage é zero byte — e o teste que
    # só olhasse o número de anexos passaria.
    it "stores the whole file, not what was left of the stream" do
      need.references.attach(pdf)

      expect(need.reload.references.first.blob.byte_size).to eq("%PDF-1.7 laudo".bytesize)
    end

    describe "a second attachment" do
      before { need.references.attach(GeotaggedPhoto.upload(filename: "primeira.jpg")) }

      # `Attached::Many#attach` chama o writer com `blobs + attachables`, então os
      # já armazenados voltam a passar por aqui. Reprocessá-los levantaria
      # `AlreadyStored` e quebraria toda anexação a partir da segunda.
      it "keeps the files that were already stored" do
        need.references.attach(GeotaggedPhoto.upload(filename: "segunda.jpg"))

        expect(need.reload.references.count).to eq(2)
      end

      it "does not reprocess what was already stored" do
        first_size = need.reload.references.first.blob.byte_size
        need.references.attach(pdf)

        expect(need.reload.references.first.blob.byte_size).to eq(first_size)
      end
    end

    # A recusa do direct upload continua valendo, e é ela que impede o cliente de
    # entregar bytes que ninguém limpou. Ver docs/photo-policy.md.
    describe "a file that was already stored elsewhere" do
      let(:foreign) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new(GeotaggedPhoto.bytes),
                                               filename: "alheia.jpg", content_type: "image/jpeg")
      end

      it "refuses a blob handed in from outside" do
        expect { need.references.attach(foreign) }.to raise_error(ExifScrubber::AlreadyStored)
      end

      it "refuses a signed id" do
        expect { need.references.attach(foreign.signed_id) }.to raise_error(ExifScrubber::AlreadyStored)
      end
    end

    it "covers the survey documents by the same door" do
      survey = create(:site_survey)
      survey.documents.attach(GeotaggedPhoto.upload)

      expect(GeotaggedPhoto.exif_fields(survey.reload.documents.first.blob.download)).to be_empty
    end
  end
end
