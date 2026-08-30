# frozen_string_literal: true

class CardComponent < ApplicationComponent
  VARIANTS = %w[default elevated outlined].freeze

  renders_one :header
  renders_one :footer

  def initialize(variant: "default", **html_options)
    validate_inclusion!(:variant, variant, VARIANTS)
    @variant = variant
    super(**html_options)
  end

  def computed_classes
    class_merge("rounded-lg p-4 md:p-6", variant_classes, html_options[:class])
  end

  def html_attributes
    html_options.merge(class: computed_classes)
  end

  private

  def variant_classes
    {
      "default" => "bg-card border border-border",
      "elevated" => "bg-card shadow-sm",
      "outlined" => "bg-transparent border border-border",
    }.fetch(@variant)
  end
end
