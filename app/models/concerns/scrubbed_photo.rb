# frozen_string_literal: true

# Anexo cuja ingestão passa obrigatoriamente pelo `ExifScrubber`.
# Ver docs/photo-policy.md.
module ScrubbedPhoto
  extend ActiveSupport::Concern

  # Um arquivo que a libvips não abre não é foto, e nesta porta ele passa
  # intacto em vez de ser recusado — mas só depois de rebobinado. O scrubber
  # copia o IO para um temporário antes de descobrir que não consegue abri-lo,
  # e um IO no fim seria armazenado como zero byte.
  def self.scrubbed_or_intact(attachable)
    ExifScrubber.call(attachable)
  rescue ExifScrubber::Unsupported
    attachable.try(:rewind)
    attachable
  end

  class_methods do
    # Uma porta só: o `attach` do Active Storage delega ao writer
    # (`Attached::One#attach` chama `record.public_send("nome=")`), então
    # interceptar o writer cobre `foto = arquivo` e `foto.attach(arquivo)` com
    # o mesmo código.
    #
    # O `define_method` é na PRÓPRIA classe, e não num módulo do concern, e a
    # diferença decide se o override roda: o writer que o `has_one_attached`
    # gera mora em `GeneratedAssociationMethods`, um módulo INCLUÍDO na classe.
    # Método definido na classe vence módulo incluído; método definido em outro
    # módulo incluído depois perde, e o override nunca seria chamado — sem erro
    # nenhum, com a foto subindo com o GPS dentro.
    def attaches_scrubbed_photo(name)
      has_one_attached name

      define_method(:"#{name}=") { |attachable| super(ExifScrubber.call(attachable)) }
    end

    # A versão de COLEÇÃO, e ela tem semântica diferente de propósito.
    #
    # No singular o campo É uma foto, e o que não abre como imagem é recusado.
    # Aqui o campo é documentação de obra — planta em PDF, laudo, medição — com
    # foto no meio. Recusar o PDF quebraria a funcionalidade; o que não pode
    # acontecer é a foto entrar por esta porta com o GPS dentro. Então: o que
    # for imagem é limpo, o que não for passa.
    def attaches_scrubbed_files(name)
      has_many_attached name

      define_method(:"#{name}=") do |attachables|
        super(ScrubbedPhoto.scrub_each(attachables, already_stored: public_send(:"#{name}_blobs")))
      end
    end
  end

  # `Attached::Many#attach` chama o writer com `blobs + attachables` — ou seja,
  # os blobs JÁ ARMAZENADOS passam por aqui em toda anexação. O scrubber levanta
  # `AlreadyStored` para blob e para signed id, e é essa recusa que fecha a
  # porta do direct upload: ela tem de continuar valendo.
  #
  # Por isso a comparação é com a coleção do próprio registro, e não com "é um
  # blob?". Blob que já está aqui volta intacto; blob vindo de fora continua
  # sendo recusado.
  def self.scrub_each(attachables, already_stored:)
    Array(attachables).map do |attachable|
      already_stored.include?(attachable) ? attachable : scrubbed_or_intact(attachable)
    end
  end
end
