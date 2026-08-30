# frozen_string_literal: true

class StatusBadgeComponentPreview < ViewComponent::Preview
  # @param status [String] select { choices: [surveying, in_progress, paused, urgent, completed] }
  # @param size [Symbol] select { choices: [sm, md, lg] }
  def playground(status: "in_progress", size: :md)
    render(StatusBadgeComponent.new(status: status, size: size))
  end
end
