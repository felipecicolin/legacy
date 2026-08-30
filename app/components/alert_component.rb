# frozen_string_literal: true

class AlertComponent < ApplicationComponent
  SEVERITIES = {
    "warning" => { icon: "alert-triangle", classes: "border-warning bg-warning-soft text-warning" },
    "destructive" => { icon: "alert-octagon", classes: "border-destructive bg-destructive-soft text-destructive" },
  }.freeze

  Attrs = Data.define(:severity, :title, :href)
  private_constant :Attrs

  def initialize(severity:, title:, href: nil, **html_options)
    validate_inclusion!(:severity, severity, SEVERITIES.keys)
    @attrs = Attrs.new(severity: severity, title: title, href: href)
    super(**html_options)
  end

  def computed_classes
    class_merge("flex items-center gap-2 rounded-sm border px-3 py-2 font-medium", severity_config.fetch(:classes),
                html_options[:class])
  end

  def icon
    severity_config.fetch(:icon)
  end

  delegate :title, :href, to: :@attrs

  def link?
    href.present?
  end

  private

  def severity_config
    SEVERITIES.fetch(@attrs.severity)
  end
end
