# frozen_string_literal: true

class SubscriberBenefitDeliveryJob < ApplicationJob
  queue_as :default

  def initialize(...)
    super
    @run_date = Date.current
  end

  def perform
    deliver_due_benefits
  end

  private

  def deliver_due_benefits
    SubscriberBenefit.due.where(due_on: ..@run_date).monthly_reports.find_each do |benefit|
      SubscriberBenefitDelivery.new(benefit).call
    end
  end
end
