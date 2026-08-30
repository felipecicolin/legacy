# frozen_string_literal: true

class InputComponent < ApplicationComponent
  TYPES = %w[text email password number tel date textarea].freeze
  FIELD_HELPERS = {
    "text" => :text_field,
    "email" => :email_field,
    "password" => :password_field,
    "number" => :number_field,
    "tel" => :telephone_field,
    "date" => :date_field,
  }.freeze
  INPUT_CLASSES = "block min-h-11 w-full rounded-sm border border-input bg-background px-3 py-2 " \
                  "text-body text-foreground placeholder:text-muted-foreground focus-visible:outline-none " \
                  "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"

  Attrs = Data.define(:form, :attribute, :type, :options)
  private_constant :Attrs

  def initialize(form:, attribute:, type: "text", **options)
    validate_inclusion!(:type, type, TYPES)
    @attrs = Attrs.new(form: form, attribute: attribute, type: type, options: options)
    super()
  end

  def field_id(suffix = "")
    "#{@attrs.form.field_id(@attrs.attribute)}#{suffix}"
  end

  def errors
    @attrs.form.object.errors[@attrs.attribute]
  end

  def described_by
    return field_id("-error") if errors.any?
    return field_id("-hint") if @attrs.options[:hint].present?

    nil
  end

  def display_label
    label = @attrs.options[:label] || @attrs.form.object.class.human_attribute_name(@attrs.attribute)
    return label unless required?

    "#{label} (#{t('input_component.required')})"
  end

  def required?
    @attrs.options.fetch(:required, false)
  end

  def field_tag
    helper = @attrs.type == "textarea" ? :text_area : FIELD_HELPERS.fetch(@attrs.type)
    @attrs.form.public_send(helper, @attrs.attribute, input_options)
  end

  def input_options
    attributes = @attrs.options
    options = attributes.slice(:autocomplete, :inputmode, :max, :min, :step, :readonly, :data)
    options.merge(class: class_merge(INPUT_CLASSES, @attrs.options[:classes]), required: required?,
                  disabled: attributes.fetch(:disabled, false), placeholder: attributes[:placeholder],
                  aria: aria_attributes).compact
  end

  def aria_attributes
    attributes = {}
    attributes[:invalid] = true if errors.any?
    attributes[:describedby] = described_by if described_by
    attributes
  end
end
