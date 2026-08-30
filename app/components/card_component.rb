# frozen_string_literal: true

class CardComponent < ApplicationComponent
  VARIANTS = %w[default elevated outlined].freeze

  # O padding é vocabulário, e não classe passada de fora, por um motivo
  # medido: o `md:p-6` do padrão vale a partir de 48rem, que é exatamente o
  # `tablet` deste projeto — um `p-8` vindo do call site perde para ele acima
  # dessa largura, sem erro e sem aviso, e o card fica com MENOS ar no desktop
  # do que no telefone. Escolher entre nomes fecha essa porta.
  PADDINGS = {
    "default" => "p-4 md:p-6",
    "roomy" => "p-8 tablet:p-14",
  }.freeze

  renders_one :header
  renders_one :footer

  def initialize(variant: "default", padding: "default", **html_options)
    validate_inclusion!(:variant, variant, VARIANTS)
    validate_inclusion!(:padding, padding, PADDINGS.keys)
    @variant = variant
    @padding = padding
    super(**html_options)
  end

  def computed_classes
    class_merge("rounded-lg", PADDINGS.fetch(@padding), variant_classes, html_options[:class])
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
