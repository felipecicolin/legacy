# frozen_string_literal: true

class SubscriptionChargeJob < ApplicationJob
  queue_as :default

  def initialize(...)
    super
    @charge_date = Date.current
  end

  def perform
    charge_due_subscriptions.find_each(&:charge_due!)
  end

  private

  def charge_due_subscriptions
    Subscription.due_for_charge.where("COALESCE(retry_on, next_charge_on) <= ?", @charge_date)
  end
end
