# frozen_string_literal: true

# Repasse simulado para uma ONG. O registro mantém o histórico da saída sem
# criar uma segunda fronteira de pagamento: quando houver um adaptador real,
# os mesmos campos continuam descrevendo o lançamento.
class Disbursement < ApplicationRecord
  include Sensitive

  STATUSES = { scheduled: 0, executed: 1, cancelled: 2 }.freeze

  belongs_to :ngo
  belongs_to :campaign, optional: true

  enum :status, STATUSES, validate: true

  attr_readonly :simulated

  validates :reference, :description, :amount_cents, :currency, :scheduled_on, :status,
            :sensitivity_level, presence: true
  validates :reference, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :simulated, inclusion: { in: [true, false] }
  validate :campaign_belongs_to_ngo
  validate :currency_matches_campaign
  validate :executed_has_date
  validate :dates_are_ordered
  validate :not_less_restrictive_than_ngo

  before_validation :inherit_ngo_sensitivity, on: :create

  def status_label
    I18n.t(status, scope: :disbursement_statuses)
  end

  def visibility_subject = ngo

  private

  def inherit_ngo_sensitivity
    return unless ngo && sensitivity_rank && ngo_rank && sensitivity_rank < ngo_rank

    self.sensitivity_level = ngo.sensitivity_level
  end

  def not_less_restrictive_than_ngo
    return unless ngo && sensitivity_rank && ngo_rank && sensitivity_rank < ngo_rank

    errors.add(:sensitivity_level, :below_ngo)
  end

  def campaign_belongs_to_ngo
    return if campaign.blank? || campaign.ngo_id == ngo_id

    errors.add(:campaign, :wrong_ngo)
  end

  def currency_matches_campaign
    return if campaign.blank? || currency.blank? || currency == campaign.currency

    errors.add(:currency, :currency_mismatch)
  end

  def executed_has_date
    return unless executed? && executed_on.blank?

    errors.add(:executed_on, :blank)
  end

  def dates_are_ordered
    return if scheduled_on.blank? || executed_on.blank? || executed_on >= scheduled_on

    errors.add(:executed_on, :after_scheduled)
  end

  def sensitivity_rank
    Sensitive::LEVELS[sensitivity_level.to_s.to_sym]
  end

  def ngo_rank
    Sensitive::LEVELS[ngo.try(:sensitivity_level).to_s.to_sym]
  end
end
