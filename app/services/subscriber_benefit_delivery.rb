# frozen_string_literal: true

class SubscriberBenefitDelivery
  def initialize(benefit)
    @benefit = benefit
  end

  def call
    @benefit.prepare!
    send_mail if @benefit.delivery_address
    @benefit.deliver!
  end

  private

  def send_mail
    SubscriberBenefitMailer.monthly_report(@benefit).deliver_now
  end
end
