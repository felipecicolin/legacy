# frozen_string_literal: true

class MetricTileComponent < ApplicationComponent
  Attrs = Data.define(:label, :value, :icon, :pending)
  private_constant :Attrs

  def initialize(label:, value: nil, icon: nil, pending: false, **html_options)
    @attrs = Attrs.new(label: label, value: value, icon: icon, pending: pending)
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: class_merge("rounded-lg border border-border bg-card p-4", html_options[:class]))
  end

  delegate :label, :icon, :pending, to: :@attrs

  def display_value
    pending ? t("metric_tile_component.pending_value") : @attrs.value
  end

  def pending_note
    t("metric_tile_component.pending_note") if pending
  end
end
