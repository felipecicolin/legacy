# frozen_string_literal: true

class MetricTileComponentPreview < ViewComponent::Preview
  def playground
    render(MetricTileComponent.new(label: "Obras ativas", value: "42", icon: "hard-hat"))
  end

  def pending
    render(MetricTileComponent.new(label: "Arrecadado no mês", icon: "chart-bar", pending: true))
  end
end
