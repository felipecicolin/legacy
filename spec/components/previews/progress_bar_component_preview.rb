# frozen_string_literal: true

class ProgressBarComponentPreview < ViewComponent::Preview
  def physical
    render(ProgressBarComponent.new(kind: "physical", value: 62))
  end

  def funding
    render(ProgressBarComponent.new(kind: "funding", value: 184_000, target: 300_000))
  end
end
