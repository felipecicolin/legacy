# frozen_string_literal: true

class AlertComponentPreview < ViewComponent::Preview
  # @param severity [String] select { choices: [warning, destructive] }
  def playground(severity: "warning")
    render(AlertComponent.new(severity: severity, title: "3 obras paradas há mais de 15 dias", href: "/obras"))
  end
end
