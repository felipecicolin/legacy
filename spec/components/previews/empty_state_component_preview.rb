# frozen_string_literal: true

class EmptyStateComponentPreview < ViewComponent::Preview
  def default
    render(EmptyStateComponent.new(icon: "blueprint", title: "Nenhuma obra cadastrada ainda",
                                   description: "Crie a primeira obra para começar a acompanhar o avanço."))
  end

  def with_action
    render(EmptyStateComponent.new(icon: "blueprint", title: "Nenhuma obra cadastrada ainda")) do |state|
      state.with_action do
        render(ButtonComponent.new(label: "Cadastrar obra", href: "#"))
      end
    end
  end
end
