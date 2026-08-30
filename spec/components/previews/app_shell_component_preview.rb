# frozen_string_literal: true

class AppShellComponentPreview < ViewComponent::Preview
  def default
    render(AppShellComponent.new) do |shell|
      shell.with_navigation_content('<a class="text-body text-foreground" href="#">Visão geral</a>'.html_safe)
      '<p class="text-body text-foreground">Conteúdo principal</p>'.html_safe
    end
  end
end
