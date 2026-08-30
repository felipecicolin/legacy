# frozen_string_literal: true

class ToastComponent < ApplicationComponent
  SEVERITIES = {
    alert: { role: "alert", classes: "border-destructive bg-destructive-soft text-destructive" },
    notice: { role: "status", classes: "border-success bg-success-soft text-success" },
  }.freeze

  Attrs = Data.define(:severity, :message, :classes)
  private_constant :Attrs

  def initialize(severity:, message:, classes: nil)
    super()
    validate_inclusion!(:severity, severity, SEVERITIES.keys)
    @attrs = Attrs.new(severity:, message:, classes:)
  end

  def role
    severity_config.fetch(:role)
  end

  def computed_classes
    class_merge("mb-5 inline-block rounded-sm border px-3 py-2 font-medium", severity_config.fetch(:classes),
                @attrs.classes)
  end

  delegate :message, to: :@attrs

  private

  def severity_config
    SEVERITIES.fetch(@attrs.severity)
  end
end
