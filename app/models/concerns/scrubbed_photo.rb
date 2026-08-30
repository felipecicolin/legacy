# frozen_string_literal: true

# Anexo de foto cuja ingestão passa obrigatoriamente pelo `ExifScrubber`.
# Ver docs/photo-policy.md.
module ScrubbedPhoto
  extend ActiveSupport::Concern

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
  end
end
