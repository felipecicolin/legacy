# frozen_string_literal: true

require "rails_helper"

class InputComponentSpecForm
  include ActiveModel::Model

  ATTRIBUTES = %i[text email password number tel date textarea].freeze
  attr_accessor(*ATTRIBUTES)
end

INPUT_FIELD_TYPES = { "text" => "input[type='text']", "email" => "input[type='email']",
                      "password" => "input[type='password']", "number" => "input[type='number']",
                      "tel" => "input[type='tel']", "date" => "input[type='date']", "textarea" => "textarea" }.freeze

RSpec.describe InputComponent, type: :component do
  def builder(object = InputComponentSpecForm.new)
    ActionView::Helpers::FormBuilder.new(:profile, object, vc_test_controller.view_context, {})
  end

  it "renders every supported field type through the form builder" do
    INPUT_FIELD_TYPES.each { |type, selector| expect_field_type(type, selector) }
  end

  it "links a hint to the field and marks required input" do
    render_hint_input
    expect(page).to have_css("input#profile_email[required]")
    expect(page.find("input#profile_email")["aria-describedby"]).to eq("profile_email-hint")
  end

  it "links errors instead of hints and disables the field" do
    render_error_input
    expect(page).to have_css("input#profile_email[disabled][aria-invalid='true']")
    expect(page.find("input#profile_email")["aria-describedby"]).to eq("profile_email-error")
    expect(page).to have_css("#profile_email-error[role='alert']", text: "não é válido")
    expect(page).to have_no_text("Dica que não deve aparecer")
  end

  it "supports placeholder, native attributes and caller classes" do
    render_inline(described_class.new(form: builder, attribute: :text, placeholder: "Digite aqui",
                                      classes: "border-primary", autocomplete: "off"))

    expect(page).to have_css("input#profile_text[placeholder='Digite aqui'][autocomplete='off']")
    classes = page.find("input#profile_text")[:class].split
    expect(classes).to include("border-primary")
    expect(classes).not_to include("border-input")
  end

  it "rejects an unsupported field type" do
    expect { described_class.new(form: builder, attribute: :email, type: "color") }
      .to raise_error(ArgumentError, /invalid type/)
  end

  private

  def expect_field_type(type, selector)
    render_inline(described_class.new(form: builder, attribute: type.to_sym, type: type, label: "Campo"))
    expect(page).to have_css(selector)
    expect(page).to have_css("label[for='profile_#{type}']")
  end

  def render_hint_input
    render_inline(described_class.new(form: builder, attribute: :email, required: true,
                                      hint: "Usaremos este e-mail para contato.", label: "E-mail"))
  end

  def render_error_input
    object = InputComponentSpecForm.new
    object.errors.add(:email, "não é válido")
    render_inline(described_class.new(form: builder(object), attribute: :email, disabled: true,
                                      hint: "Dica que não deve aparecer", label: "E-mail"))
  end
end
