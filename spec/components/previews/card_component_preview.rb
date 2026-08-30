# frozen_string_literal: true

class CardComponentPreview < ViewComponent::Preview
  # @param variant [String] select { choices: [default, elevated, outlined] }
  # @param padding [String] select { choices: [default, roomy] }
  def playground(variant: "default", padding: "default")
    render(CardComponent.new(variant: variant, padding: padding)) do |card|
      card.with_header { "Resumo da obra" }
      "O conteúdo do cartão respeita os tokens do design system."
    end
  end
end
