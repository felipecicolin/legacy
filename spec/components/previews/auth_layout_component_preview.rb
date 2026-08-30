# frozen_string_literal: true

class AuthLayoutComponentPreview < ViewComponent::Preview
  # O padrão: o painel de apoio ocupa a metade esquerda enquanto não há foto.
  def default
    render(AuthLayoutComponent.new) do
      '<h1 class="text-display text-foreground">Acessar a plataforma</h1>'.html_safe
    end
  end

  # Com imagem: o slot ocupa exatamente o mesmo retângulo do apoio, e por isso
  # o enquadramento da tela não muda quando a foto entra.
  def with_illustration
    render(AuthLayoutComponent.new) do |auth|
      auth.with_illustration_content(
        '<div class="absolute inset-0 bg-primary"></div>'.html_safe,
      )
      '<h1 class="text-display text-foreground">Acessar a plataforma</h1>'.html_safe
    end
  end
end
