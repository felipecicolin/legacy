# frozen_string_literal: true

class ProgressBarComponent < ApplicationComponent
  KINDS = %w[physical funding spending].freeze

  # `spending` reaproveita a razão e o valor de `funding` — a matemática de
  # "quanto de um alvo" é a mesma — e muda só a cor e o rótulo: gasto contra
  # orçamento é leitura de atenção, não de conquista.
  KIND_CONFIG = {
    "physical" => { classes: "bg-primary", ratio: :physical_ratio, value: :physical_label },
    "funding" => { classes: "bg-accent", ratio: :funding_ratio, value: :funding_label },
    "spending" => { classes: "bg-warning", ratio: :funding_ratio, value: :funding_label },
  }.freeze

  Attrs = Data.define(:kind, :value, :target)
  private_constant :Attrs

  def initialize(kind:, value:, target: nil, **html_options)
    validate_inclusion!(:kind, kind, KINDS)
    @attrs = Attrs.new(kind: kind, value: value, target: target)
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: class_merge("w-full", html_options[:class]))
  end

  def progress_attributes
    { class: "h-3 w-full overflow-hidden rounded-full bg-muted",
      role: "progressbar",
      aria: { label: aria_label, valuenow: percentage, valuemin: 0, valuemax: 100 } }
  end

  def fill_attributes
    { class: class_merge("h-full rounded-full transition-[width]", kind_config.fetch(:classes)),
      style: "width: #{format('%g', percentage)}%" }
  end

  def value_label
    send(kind_config.fetch(:value))
  end

  # As três chaves escritas por extenso: `Rails/DotSeparatedKeys` recusa a
  # opção `scope:`, o cop de i18n recusa a chave montada por interpolação, e o
  # scanner de chave órfã só enxerga literal.
  def aria_label
    return t("progress_bar_component.physical_label") if @attrs.kind == "physical"
    return t("progress_bar_component.spending_label") if @attrs.kind == "spending"

    t("progress_bar_component.funding_label")
  end

  def percentage
    ratio * 100
  end

  private

  def ratio
    send(kind_config.fetch(:ratio))
  end

  def physical_ratio
    (@attrs.value.to_f / 100).clamp(0, 1)
  end

  def funding_ratio
    target = @attrs.target.to_f
    return 0 unless target.positive?

    (@attrs.value.to_f / target).clamp(0, 1)
  end

  def physical_label
    helpers.number_to_percentage(percentage, precision: 0)
  end

  def funding_label
    t("progress_bar_component.funding_value", value: currency(@attrs.value), target: target_label)
  end

  def target_label
    @attrs.target.present? ? currency(@attrs.target) : t("progress_bar_component.without_target")
  end

  def currency(value)
    helpers.number_to_currency(value, locale: :"pt-BR")
  end

  def kind_config
    KIND_CONFIG.fetch(@attrs.kind)
  end
end
