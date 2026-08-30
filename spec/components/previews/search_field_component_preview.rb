# frozen_string_literal: true

class SearchFieldComponentPreview < ViewComponent::Preview
  def default
    render(SearchFieldComponent.new(url: "#", frame: "results", value: "obra"))
  end
end
