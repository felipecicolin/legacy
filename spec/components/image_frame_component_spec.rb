# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageFrameComponent, type: :component do
  # `create_before_direct_upload!` persiste a linha sem subir bytes: basta o id
  # para a URL de representação ser assinada, e nenhuma variante é processada
  # na renderização (o Active Storage só processa quando a URL é pedida). Assim
  # o spec do componente não depende da libvips nem do disco.
  def blob_for(content_type: "image/png", analyzed: true)
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "obra.png", byte_size: 1_234, checksum: "sem-bytes", content_type: content_type,
    )
    blob.update!(metadata: { "analyzed" => true, "identified" => true }) if analyzed
    blob
  end

  let(:alt) { "Fachada da obra" }

  describe "validation" do
    it "refuses a ratio outside the scale" do
      expect { described_class.new(attachment: nil, alt: alt, ratio: "21/9") }
        .to raise_error(ArgumentError, /invalid ratio/)
    end
  end

  describe "when there is nothing to show" do
    it "renders the neutral frame instead of an image when nothing is attached" do
      render_inline(described_class.new(attachment: nil, alt: alt))

      expect(page).to have_no_css("img")
      expect(page).to have_text("Sem imagem")
    end

    it "treats an empty attachment proxy as nothing attached" do
      proxy = instance_double(ActiveStorage::Attached::One, attached?: false)

      render_inline(described_class.new(attachment: proxy, alt: alt))

      expect(page).to have_text("Sem imagem")
    end

    # Um PDF ou um .txt nunca vira variante, então "processando" seria mentira:
    # nada está em curso.
    it "does not promise processing for a file that can never be represented" do
      render_inline(described_class.new(attachment: blob_for(content_type: "text/plain"), alt: alt))

      expect(page).to have_text("Sem imagem")
      expect(page).to have_no_text("Processando")
    end

    # Um PDF (ou um vídeo) é `representable?`: o Active Storage sabe extrair uma
    # capa dele com o poppler ou o ffmpeg. Mas ele nunca é `variable?`, e
    # `blob.variant` sobre ele levanta `ActiveStorage::InvariableError` — o que
    # a `<img>` pede aqui é variante, não prévia.
    #
    # `previewable?` é estubado porque a resposta de verdade depende de o
    # poppler estar instalado na máquina: sem o estube este spec ficaria verde
    # num runner sem poppler mesmo com o bug de volta.
    it "does not build a variant out of a file that is only previewable" do
      blob = blob_for(content_type: "application/pdf")
      allow(blob).to receive(:previewable?).and_return(true)

      render_inline(described_class.new(attachment: blob, alt: alt))

      expect(page).to have_no_css("img")
      expect(page).to have_text("Sem imagem")
    end
  end

  describe "when the variant is still being processed" do
    it "holds the frame with a placeholder instead of an image" do
      render_inline(described_class.new(attachment: blob_for(analyzed: false), alt: alt))

      expect(page).to have_no_css("img")
      expect(page).to have_css("div.aspect-wide")
      expect(page).to have_text("Processando a imagem")
    end
  end

  describe "when the image is ready" do
    it "serves the three widths through srcset" do
      render_inline(described_class.new(attachment: blob_for, alt: alt))

      srcset = page.find("img")[:srcset]

      expect(srcset.scan(/(\d+)w/).flatten).to eq(%w[480 960 1440])
    end

    it "defers the download and keeps decoding off the main thread" do
      render_inline(described_class.new(attachment: blob_for, alt: alt))

      expect(page).to have_css("img[loading='lazy'][decoding='async']")
      expect(page.find("img")[:sizes]).to eq(described_class::DEFAULT_SIZES)
    end

    it "keeps an explicitly empty alt as an empty attribute, never a missing one" do
      render_inline(described_class.new(attachment: blob_for, alt: ""))

      expect(page.find("img")[:alt]).to eq("")
    end

    it "hides the fallback from screen readers, since the alt already describes the image" do
      render_inline(described_class.new(attachment: blob_for, alt: alt))

      expect(page).to have_css("div[aria-hidden='true']", text: "Não foi possível carregar")
    end

    it "reads the blob out of an attachment record as happily as out of a blob" do
      attachment = instance_double(ActiveStorage::Attachment, blob: blob_for)

      render_inline(described_class.new(attachment: attachment, alt: alt))

      expect(page).to have_css("img[srcset]")
    end
  end

  describe "ratio" do
    it "reserves the space with a semantic aspect utility, never an arbitrary value" do
      described_class::RATIO_CLASSES.each do |ratio, utility|
        render_inline(described_class.new(attachment: nil, alt: alt, ratio: ratio))

        expect(page).to have_css("div.#{utility}")
      end
    end

    it "lets the caller's classes win over the frame defaults" do
      render_inline(described_class.new(attachment: nil, alt: alt, classes: "rounded-sm"))

      expect(page).to have_css("div.rounded-sm")
      expect(page).to have_no_css("div.rounded-lg")
    end
  end

  describe "caption" do
    it "renders the caption the caller decided to show" do
      render_inline(described_class.new(attachment: nil, alt: alt)) do |frame|
        frame.with_caption { "12 de março de 2026 · Marina Duarte" }
      end

      expect(page).to have_css("figcaption", text: "Marina Duarte")
    end

    it "omits the figcaption entirely when there is no caption" do
      render_inline(described_class.new(attachment: nil, alt: alt))

      expect(page).to have_no_css("figcaption")
    end
  end
end
