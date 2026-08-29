# frozen_string_literal: true

# Os exemplos usam blobs de verdade porque `srcset` de variante só existe com
# um blob persistido: a URL de representação é assinada a partir do id. Um
# dobrê não chegaria a produzir uma URL, e o preview deixaria de provar o que
# promete — ver docs/design-system/image-frame.md.
class ImageFrameComponentPreview < ViewComponent::Preview
  PHOTO = Rails.root.join("spec/fixtures/files/obra.png")
  ALT = "Fachada da obra vista da rua, com o andaime montado"

  def playground
    render(ImageFrameComponent.new(attachment: analyzed_photo, alt: ALT))
  end

  def four_by_three
    render(ImageFrameComponent.new(attachment: analyzed_photo, alt: ALT, ratio: "4/3"))
  end

  def square
    render(ImageFrameComponent.new(attachment: analyzed_photo, alt: ALT, ratio: "1/1"))
  end

  def with_caption
    render(ImageFrameComponent.new(attachment: analyzed_photo, alt: ALT)) do |frame|
      frame.with_caption { "12 de março de 2026 · Marina Duarte" }
    end
  end

  # Variante ainda não processada: o quadro de apoio ocupa o mesmo
  # enquadramento, então a imagem entra sem empurrar o que vem depois.
  def processing
    render(ImageFrameComponent.new(attachment: pending_photo, alt: ALT))
  end

  # `alt: ""` explícito: uma moldura vazia não descreve nada, e omitir o
  # atributo faria o leitor de tela ler o nome do arquivo.
  def without_attachment
    render(ImageFrameComponent.new(attachment: nil, alt: ""))
  end

  private

  def analyzed_photo
    blob = ActiveStorage::Blob.find_by(filename: PHOTO.basename.to_s) || upload_photo
    blob.analyze unless blob.analyzed?
    blob
  end

  def upload_photo
    ActiveStorage::Blob.create_and_upload!(io: PHOTO.open, filename: PHOTO.basename.to_s,
                                           content_type: "image/png")
  end

  # Sem bytes: o registro existe, a variante ainda não. É o estado em que o
  # upload direto deixa o blob antes de o navegador terminar de enviá-lo.
  def pending_photo
    ActiveStorage::Blob.find_by(filename: "obra-em-envio.png") ||
      ActiveStorage::Blob.create_before_direct_upload!(
        filename: "obra-em-envio.png", byte_size: 1, checksum: "pendente", content_type: "image/png",
      )
  end
end
