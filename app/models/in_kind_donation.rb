# frozen_string_literal: true

class InKindDonation < ApplicationRecord
  CATEGORIES = { material: 0, equipment: 1, expertise: 2, service: 3, transport: 4 }.freeze
  STATUSES = { offered: 0, accepted: 1, in_transit: 2, delivered: 3, declined: 4 }.freeze
  COUNTED_STATUSES = %w[accepted in_transit delivered].freeze

  belongs_to :donor, polymorphic: true
  belongs_to :campaign, optional: true
  has_rich_text :specification
  has_many_attached :documents

  enum :category, CATEGORIES, validate: true
  enum :status, STATUSES, validate: true

  scope :accepted_for_total, -> { where(status: COUNTED_STATUSES).where.not(estimated_value_cents: nil) }
  scope :in_triage, -> { offered.where(need_id: nil) }

  validates :category, :title, :quantity, :status, :currency, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :estimated_value_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validate :currency_matches_campaign
  validate :delivered_has_date
  validate :declined_has_reason
  validate :skilled_donation_uses_hours

  after_destroy :refresh_campaign
  after_save :refresh_campaign

  def accept
    update!(status: :accepted)
  end
  alias accept! accept

  def deliver
    update!(status: :delivered, delivered_on: Date.current)
  end
  alias deliver! deliver

  def decline(reason:)
    update!(status: :declined, decline_reason: reason)
  end
  alias decline! decline

  def category_label
    I18n.t(category, scope: :in_kind_categories)
  end

  def accepted_for_total?
    COUNTED_STATUSES.include?(status)
  end

  private

  def currency_matches_campaign
    return if campaign.blank? || currency == campaign.currency

    errors.add(:currency, :currency_mismatch)
  end

  def delivered_has_date
    return unless delivered? && delivered_on.blank?

    errors.add(:delivered_on, :blank)
  end

  def declined_has_reason
    return unless declined? && decline_reason.blank?

    errors.add(:decline_reason, :blank)
  end

  def skilled_donation_uses_hours
    return unless %w[expertise service].include?(category) && unit.to_s.downcase != "hora"

    errors.add(:unit, :hours_required)
  end

  def refresh_campaign
    campaign&.recalculate_raised_cents!
  end
end
