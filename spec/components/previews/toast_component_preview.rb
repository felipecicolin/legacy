# frozen_string_literal: true

class ToastComponentPreview < ViewComponent::Preview
  def alert
    render ToastComponent.new(severity: :alert, message: t("sessions.create.failed"))
  end

  def notice
    render ToastComponent.new(severity: :notice, message: t("passwords.create.sent"))
  end
end
