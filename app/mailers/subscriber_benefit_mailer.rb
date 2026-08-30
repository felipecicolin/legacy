# frozen_string_literal: true

class SubscriberBenefitMailer < ApplicationMailer
  def monthly_report(benefit)
    @benefit = benefit
    mail to: benefit.delivery_address, subject: t("subscriber_benefits.monthly_report.subject")
  end
end
