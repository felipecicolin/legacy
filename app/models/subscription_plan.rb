# frozen_string_literal: true

class SubscriptionPlan < ApplicationRecord
  INTERVALS = { monthly: 0, quarterly: 1, yearly: 2 }.freeze

  has_many :subscriptions, dependent: :restrict_with_error

  enum :interval, INTERVALS, validate: true

  validates :key, :amount_cents, :currency, :interval, presence: true
  validates :key, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [true, false] }

  def interval_label
    I18n.t(interval, scope: :subscription_intervals)
  end

  def next_date(date)
    date.advance(months: interval_months)
  end

  private

  def interval_months
    { "monthly" => 1, "quarterly" => 3, "yearly" => 12 }.fetch(interval)
  end
end
