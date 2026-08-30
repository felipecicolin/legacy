# frozen_string_literal: true

class StatusBadgeComponent < ApplicationComponent
  STATUSES = {
    "surveying" => { token: "muted", icon: "clock", classes: "bg-muted text-muted-foreground" },
    "in_progress" => { token: "success", icon: "hard-hat", classes: "bg-success text-success-foreground" },
    "paused" => { token: "warning", icon: "pause-circle", classes: "bg-warning text-warning-foreground" },
    "urgent" => { token: "destructive", icon: "alert-triangle", classes: "bg-destructive text-destructive-foreground" },
    "completed" => { token: "accent", icon: "check-circle", classes: "bg-accent text-accent-foreground" },
  }.freeze

  SIZES = {
    sm: "px-2 py-1 text-xs",
    md: "px-2.5 py-1.5 text-xs",
    lg: "px-3 py-2 text-sm",
  }.freeze

  def initialize(status:, size: :md, **html_options)
    validate_inclusion!(:status, status.to_s, STATUSES.keys)
    validate_inclusion!(:size, size, SIZES.keys)
    @status = status.to_s
    @size = size
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: computed_classes)
  end

  def computed_classes
    # A cor DEPOIS do tamanho, de propósito: `text-*` de cor e `text-*` de
    # tamanho disputam grupo no merger, e quem chega por último sobrevive.
    class_merge("inline-flex items-center gap-1.5 rounded-full font-semibold",
                SIZES.fetch(@size), status_classes, html_options[:class])
  end

  def status_icon
    status_config.fetch(:icon)
  end

  def label
    I18n.t(@status, scope: :project_statuses)
  end

  private

  def status_config
    STATUSES.fetch(@status)
  end

  def status_classes
    status_config.fetch(:classes)
  end
end
