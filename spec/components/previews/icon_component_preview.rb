# frozen_string_literal: true

class IconComponentPreview < ViewComponent::Preview
  # @param name [Symbol] select { choices: [check, x, plus, search, trash, alert-triangle] }
  # @param size [Symbol] select { choices: [xs, sm, md, lg, xl] }
  def playground(name: "check", size: :md)
    render(IconComponent.new(name: name, size: size))
  end

  # Um ícone com rótulo é conteúdo, e ganha `title` em vez de sair do fluxo de
  # leitores de tela.
  def labelled
    render(IconComponent.new(name: "alert-triangle", size: :lg, label: "Atenção"))
  end
end
