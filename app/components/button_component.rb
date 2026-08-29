# frozen_string_literal: true

class ButtonComponent < ApplicationComponent
  VARIANTS = {
    default: "bg-primary text-primary-foreground shadow-md hover:shadow-lg hover:brightness-105 " \
             "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
    outline: "bg-transparent text-primary border-[1.5px] border-primary hover:bg-primary-soft " \
             "hover:shadow-sm focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
    ghost: "bg-transparent text-foreground hover:bg-muted focus-visible:ring-2 " \
           "focus-visible:ring-ring focus-visible:ring-offset-1",
    destructive: "bg-destructive text-destructive-foreground shadow-md hover:shadow-lg " \
                 "hover:brightness-110 focus-visible:ring-2 focus-visible:ring-destructive " \
                 "focus-visible:ring-offset-2",
    soft: "bg-primary-soft text-primary hover:brightness-95 focus-visible:ring-2 " \
          "focus-visible:ring-ring focus-visible:ring-offset-2",
    link: "bg-transparent text-primary underline-offset-4 hover:underline shadow-none " \
          "focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
  }.freeze

  SIZES = {
    sm: "h-9 px-3.5 text-sm rounded-lg gap-1.5",
    md: "h-11 px-5 text-sm rounded-xl gap-2",
    lg: "h-12 px-6 text-base rounded-xl gap-2",
    icon: "h-10 w-10 rounded-lg",
  }.freeze

  TYPES = %i[button submit reset].freeze

  # Um Data em vez de oito ivars: o `TooManyInstanceVariables` do reek está
  # ligado e está certo — oito estados soltos num objeto são difíceis de ler.
  Attrs = Data.define(:label, :variant, :size, :type, :disabled, :href, :classes, :data)
  private_constant :Attrs

  renders_one :leading_icon, IconComponent
  renders_one :trailing_icon, IconComponent

  def initialize(label: nil, variant: :default, size: :md, type: :button,
                 disabled: false, href: nil, classes: nil, data: nil)
    super()
    validate_inputs!(variant, size, type)
    @attrs = Attrs.new(label: label, variant: variant, size: size, type: type,
                       disabled: disabled, href: href, classes: classes, data: data)
  end

  def computed_classes
    class_merge(base_classes, VARIANTS.fetch(@attrs.variant), SIZES.fetch(@attrs.size), @attrs.classes)
  end

  def link?
    @attrs.href.present?
  end

  delegate :label, :type, :disabled, :href, :data, to: :@attrs

  private

  def validate_inputs!(variant, size, type)
    validate_inclusion!(:variant, variant, VARIANTS.keys)
    validate_inclusion!(:size, size, SIZES.keys)
    validate_inclusion!(:type, type, TYPES)
  end

  def base_classes
    "inline-flex items-center justify-center font-semibold whitespace-nowrap cursor-pointer " \
      "transition-all duration-150 ease-out focus-visible:outline-none " \
      "disabled:pointer-events-none disabled:opacity-50"
  end
end
