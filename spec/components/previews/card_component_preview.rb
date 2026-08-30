# frozen_string_literal: true

class CardComponentPreview < ViewComponent::Preview
  # @param variant [String] select { choices: [default, elevated, outlined] }
  def playground(variant: "default")
    render(CardComponent.new(variant: variant)) do |card|
      card.with_header { "Resumo da obra" }
      "O conteúdo do cartão respeita os tokens do design system."
    end
  end
end
