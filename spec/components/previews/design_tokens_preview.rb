# frozen_string_literal: true

# Página de fumaça dos tokens semânticos — o host de
# `spec/system/design_tokens_spec.rb`.
#
# É um preview, e não uma rota, porque os previews já estão ligados em teste
# (`previews.enabled` cai para `development? || test?`): assim o spec ganha uma
# URL de verdade sem que #6 escreva rota, controller ou view de aplicação — o
# `config/routes.rb` é de #57, e um controller a mais seria código de produção
# existindo só para o teste.
#
# Não tem componente correspondente de propósito: não é peça da biblioteca, é
# instrumento de medição. O `bin/components_registry` varre componentes e só
# então procura o preview, então esta classe não entra no registry.
class DesignTokensPreview < ViewComponent::Preview
  def default
    render_with_template(template: "design_tokens_preview/default")
  end
end
