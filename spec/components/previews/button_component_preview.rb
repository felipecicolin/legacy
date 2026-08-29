# frozen_string_literal: true

class ButtonComponentPreview < ViewComponent::Preview
  # @param variant [Symbol] select { choices: [default, outline, ghost, destructive, soft, link] }
  # @param size [Symbol] select { choices: [sm, md, lg, icon] }
  # @param disabled toggle
  # @param label text
  def playground(variant: :default, size: :md, disabled: false, label: "Salvar alterações")
    render(ButtonComponent.new(label: label, variant: variant, size: size, disabled: disabled))
  end

  def as_link
    render(ButtonComponent.new(label: "Voltar ao painel", variant: :outline, href: "#"))
  end

  def disabled_state
    render(ButtonComponent.new(label: "Aguardando…", disabled: true))
  end

  def with_leading_icon
    render(ButtonComponent.new(label: "Adicionar")) do |button|
      button.with_leading_icon(name: "plus", size: :sm)
    end
  end
end
