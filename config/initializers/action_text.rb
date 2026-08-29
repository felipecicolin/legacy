# frozen_string_literal: true

# Política de anexo embutido em texto rico — ver docs/action-text.md.
#
# O Trix embute imagem criando um blob do Active Storage e referenciando-o por
# `action-text-attachment`. Esse caminho não passa pelo processamento de foto da
# plataforma (limpeza de EXIF, entrega autorizada), então um campo de texto rico
# num recurso confidencial viraria porta lateral para publicar imagem sem
# controle. A decisão da #32 é a primeira das duas ofertas da issue: campo de
# texto rico SEM anexo embutido.
#
# Duas linhas, e as duas importam:
#
#   * tirar `ActionText::Attachment.tag_name` da lista de tags permitidas faz o
#     sanitizador remover o elemento de anexo;
#   * `prune: true` faz ele remover TAMBÉM o conteúdo do elemento. Sem isso o
#     `PermitScrubber` desembrulha o nó em vez de podá-lo, e o `img` já
#     renderizado lá dentro sobrevive — com a URL do blob, que é exatamente o
#     que a política quer impedir. Verificado neste repositório.
#
# O `prune` vale para toda tag não permitida, e é uma melhora fora do anexo
# também: `<script>alert(1)</script>` some inteiro, em vez de deixar o texto
# `alert(1)` para trás.
#
# `figure` e `figcaption` seguem permitidos porque é o que a lista padrão do
# Action Text acrescenta — o que foi subtraído aqui é só o elemento de anexo.
#
# O gancho é `after_initialize` + `on_load(:action_view)`, e não um `to_prepare`,
# porque a própria `ActionText::Engine` atribui o sanitizador nesse par de
# ganchos (`config.after_initialize` dela). Atribuir antes não levanta erro
# nenhum: só é sobrescrito depois, e a política some em silêncio. Registrar
# daqui garante a última palavra, porque o `after_initialize` da aplicação é
# registrado depois do da engine.
Rails.application.config.after_initialize do |app|
  # O vendor sai da config do framework para acompanhar o `load_defaults`: em
  # 8.1 ele é o HTML5. Fixá-lo aqui congelaria o parser numa versão.
  vendor = app.config.action_text.sanitizer_vendor || Rails::HTML4::Sanitizer
  sanitizer = vendor.safe_list_sanitizer

  ActiveSupport.on_load(:action_view) do
    ActionText::ContentHelper.sanitizer = sanitizer.new(prune: true)
    ActionText::ContentHelper.allowed_tags = sanitizer.allowed_tags + %w[figure figcaption]
  end
end
