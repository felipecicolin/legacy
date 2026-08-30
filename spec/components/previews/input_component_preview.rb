# frozen_string_literal: true

class InputComponentPreview < ViewComponent::Preview
  PreviewForm = Class.new do
    include ActiveModel::Model

    attr_accessor :email
  end

  def default
    render(InputComponent.new(form: form_builder, attribute: :email, type: "email",
                              required: true, hint: "Usaremos este endereço para falar com você."))
  end

  private

  def form_builder
    ActionView::Helpers::FormBuilder.new(:profile, PreviewForm.new, helpers, {})
  end
end
