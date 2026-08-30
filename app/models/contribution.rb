# frozen_string_literal: true

# Lançamento de arrecadação. Todos os canais compartilham esta tabela para que
# o total da campanha tenha uma única definição.
class Contribution < ApplicationRecord
  STATUSES = { pending: 0, confirmed: 1, failed: 2, refunded: 3 }.freeze
  ORIGINS = { one_off: 0, subscription: 1, event: 2, store: 3 }.freeze
  PAYMENT_STATUS_MAP = { succeeded: :confirmed, refused: :failed }.freeze

  belongs_to :campaign, optional: true
  belongs_to :contributor, polymorphic: true, optional: true
  belongs_to :subscription, optional: true
  has_one :receipt, dependent: :restrict_with_error
  has_one :event_registration, dependent: :nullify

  enum :status, STATUSES, validate: true
  enum :origin, ORIGINS, validate: true, scopes: false

  scope :counted, -> { confirmed }
  scope :publicly_counted, -> { counted }

  attr_readonly :simulated

  validates :amount_cents, :currency, :status, :origin, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validates :simulated, inclusion: { in: [true, false] }
  validates :provider_reference, uniqueness: true, allow_nil: true
  validate :campaign_accepts_contribution
  validate :campaign_required_for_origin
  validate :currency_matches_campaign
  validate :subscription_origin_is_linked

  after_destroy :refresh_campaign
  after_save :refresh_campaign
  after_save :issue_receipt, if: :saved_change_to_status_to_confirmed?

  def process
    result = Payments::Gateway.new.charge(payment_request)
    apply_payment_result(result)
    result
  end
  alias process! process

  def confirm
    update!(status: :confirmed, confirmed_at: Time.current)
  end
  alias confirm! confirm

  def refund
    result = Payments::Gateway.new.refund(payment_request)
    update!(status: :refunded) if result.status.to_sym == :succeeded
    result
  end
  alias refund! refund

  def public_contributor(context: Visibility::Context.anonymous)
    return if anonymous? || campaign.blank? || !context.can_identify?(campaign)

    contributor
  end

  def visibility_subject = campaign

  private

  def campaign_accepts_contribution
    return if campaign.blank? || campaign.accepting_contributions?

    errors.add(:campaign, :not_accepting_contributions)
  end

  def campaign_required_for_origin
    return if campaign.present? || origin == "subscription"

    errors.add(:campaign, :blank)
  end

  def currency_matches_campaign
    return if campaign.blank? || currency.blank? || currency == campaign.currency

    errors.add(:currency, :currency_mismatch)
  end

  def subscription_origin_is_linked
    return unless origin == "subscription" && subscription.blank?

    errors.add(:subscription, :blank)
  end

  def payment_request
    Payments::Request.new(amount_cents:, currency:, reference: "contribution-#{id}")
  end

  def apply_payment_result(result)
    status = result.status.to_sym
    attributes = { status: PAYMENT_STATUS_MAP.fetch(status, status), provider_reference: result.provider_reference }
    attributes[:confirmed_at] = result.processed_at if status == :succeeded
    update!(attributes)
  end

  def saved_change_to_status_to_confirmed?
    saved_change_to_status? && confirmed?
  end

  def issue_receipt
    Receipt.find_or_create_by!(contribution: self)
  end

  def refresh_campaign
    campaign&.recalculate_raised_cents!
  end
end
