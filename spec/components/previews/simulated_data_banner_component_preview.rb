# frozen_string_literal: true

class SimulatedDataBannerComponentPreview < ViewComponent::Preview
  def default
    render(SimulatedDataBannerComponent.new)
  end

  # Como o banner cabe numa coluna de conteúdo, que é onde o layout o põe.
  def inside_a_container
    render(SimulatedDataBannerComponent.new(classes: "container mx-auto"))
  end
end
