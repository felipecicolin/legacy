# frozen_string_literal: true

class FundraisingDashboardComponent < ApplicationComponent
  STATUS_CLASSES = {
    "active" => "bg-success-soft text-success",
    "accepted" => "bg-success-soft text-success",
    "cancelled" => "bg-muted text-muted-foreground",
    "closed" => "bg-muted text-muted-foreground",
    "declined" => "bg-destructive-soft text-destructive",
    "delivered" => "bg-success-soft text-success",
    "draft" => "bg-muted text-muted-foreground",
    "executed" => "bg-success-soft text-success",
    "failed" => "bg-destructive-soft text-destructive",
    "in_transit" => "bg-primary-soft text-primary",
    "offered" => "bg-primary-soft text-primary",
    "paused" => "bg-warning-soft text-warning",
    "past_due" => "bg-warning-soft text-warning",
    "pending" => "bg-warning-soft text-warning",
    "reached" => "bg-success-soft text-success",
    "scheduled" => "bg-primary-soft text-primary",
  }.freeze
  CHANNEL_LABEL_KEYS = {
    one_off: "fundraising_dashboard_component.channels.one_off",
    recurring: "fundraising_dashboard_component.channels.recurring",
    in_kind: "fundraising_dashboard_component.channels.in_kind",
    event_store: "fundraising_dashboard_component.channels.event_store",
  }.freeze

  def initialize(presenter:)
    @presenter = presenter
    super()
  end

  attr_reader :presenter

  def channel_label(key) = t(CHANNEL_LABEL_KEYS.fetch(key))

  def money(cents)
    helpers.money_from_cents(cents)
  end

  def date_label(date)
    return t("fundraising_dashboard_component.not_available") unless date

    helpers.l(date)
  end

  def status_badge(status, label)
    helpers.tag.span(label, class: status_classes(status), data: { status: status })
  end

  def status_classes(status)
    class_merge("inline-flex rounded-full px-2 py-1 text-label font-semibold", STATUS_CLASSES.fetch(status))
  end
end
