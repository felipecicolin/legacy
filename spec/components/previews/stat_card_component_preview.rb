# frozen_string_literal: true

class StatCardComponentPreview < ViewComponent::Preview
  def default
    render(StatCardComponent.new(label: "Total aportado", value: "R$ 56.000,00"))
  end

  def with_hint
    render(StatCardComponent.new(label: "Pessoas alcançadas", value: "15.787",
                                 hint: "por ano, pela fatia que você financia"))
  end
end
