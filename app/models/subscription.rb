# frozen_string_literal: true

class Subscription < ApplicationRecord
  STATUSES = { active: 0, past_due: 1, paused: 2, cancelled: 3 }.freeze
  DUE_FOR_CHARGE_SCOPE = lambda do
    where(status: %i[active past_due]).where("COALESCE(retry_on, next_charge_on) <= ?", Date.current)
  end

  belongs_to :subscription_plan
  belongs_to :subscriber, polymorphic: true
  belongs_to :campaign, optional: true
  has_many :contributions, dependent: :restrict_with_error
  has_many :subscriber_benefits, dependent: :destroy

  enum :status, STATUSES, validate: true

  scope :due_for_charge, DUE_FOR_CHARGE_SCOPE

  attr_readonly :simulated

  validates :started_on, :next_charge_on, :status, presence: true
  validates :cycles_completed, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :simulated, inclusion: { in: [true, false] }
  validate :plan_is_active
  validate :campaign_currency_matches_plan
  validate :dates_are_ordered

  def charge_due
    with_lock { charge_locked if due_for_charge? }
  end
  alias charge_due! charge_due

  def cancel
    update!(status: :cancelled, cancelled_on: Date.current)
    skip_unearned_benefit
  end
  alias cancel! cancel

  def pause
    update!(status: :paused)
  end
  alias pause! pause

  def resume
    update!(status: :active)
  end
  alias resume! resume

  def due_for_charge?
    (active? || past_due?) && (retry_on || next_charge_on) <= Date.current
  end

  def idempotency_key
    "subscription-#{id}-#{next_charge_on}"
  end

  def currency
    subscription_plan&.currency
  end

  private

  def charge_locked
    contribution = find_or_build_contribution
    contribution.save! if contribution.new_record?
    contribution.process!
    return mark_past_due unless contribution.confirmed?

    complete_cycle
    contribution
  end

  def find_or_build_contribution
    contributions.find_or_initialize_by(idempotency_key:).tap do |contribution|
      contribution.assign_attributes(campaign:, amount_cents: subscription_plan.amount_cents,
                                     currency:, origin: :subscription, status: :pending)
    end
  end

  def mark_past_due
    update!(status: :past_due, retry_on: Date.current + 1.day)
    nil
  end

  def complete_cycle
    due_on = next_charge_on
    update!(status: :active, cycles_completed: cycles_completed + 1,
            next_charge_on: subscription_plan.next_date(due_on), retry_on: nil)
    SubscriberBenefit.create_for_cycle!(self, due_on)
  end

  def skip_unearned_benefit
    return if cycles_completed >= 6

    SubscriberBenefit.skip_gift_for!(self, "subscription_cancelled_before_six_cycles")
  end

  def plan_is_active
    return if subscription_plan.blank? || subscription_plan.active?

    errors.add(:subscription_plan, :inactive)
  end

  def campaign_currency_matches_plan
    return if campaign.blank? || campaign.currency == subscription_plan&.currency

    errors.add(:campaign, :currency_mismatch)
  end

  def dates_are_ordered
    return if next_charge_on.blank? || started_on.blank? || next_charge_on >= started_on

    errors.add(:next_charge_on, :after_start)
  end
end
