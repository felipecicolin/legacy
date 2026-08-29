# frozen_string_literal: true

# Página de fumaça do editor de texto rico — o host de
# `spec/system/rich_text_editor_spec.rb`.
#
# É preview, e não rota, pelo mesmo motivo do `DesignTokensPreview`: os previews
# já estão ligados em teste, então o spec ganha uma URL de verdade sem que a #32
# escreva rota, controller ou view de aplicação.
#
# Existe porque duas das decisões desta issue só se verificam num navegador: a
# barra do Trix em pt-BR e a ausência do botão de anexar. Nenhum linter deste
# repositório lê JavaScript de terceiro nem CSS compilado — os dois quebram sem
# erro em lugar nenhum.
#
# Não tem componente correspondente: não é peça da biblioteca, é instrumento de
# medição, e por isso não entra no `bin/components_registry`.
class RichTextEditorPreview < ViewComponent::Preview
  def default
    render_with_template(template: "rich_text_editor_preview/default")
  end
end
