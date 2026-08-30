# frozen_string_literal: true

class ErrorPageComponentPreview < ViewComponent::Preview
  def forbidden
    render ErrorPageComponent.new(status: :forbidden)
  end

  def internal_server_error
    render ErrorPageComponent.new(status: :internal_server_error)
  end

  def not_found
    render ErrorPageComponent.new(status: :not_found)
  end

  def unprocessable_entity
    render ErrorPageComponent.new(status: :unprocessable_entity)
  end
end
