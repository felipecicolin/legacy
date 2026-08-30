# frozen_string_literal: true

class Partnership < ApplicationRecord
  include Sensitive

  KINDS = { material_supplier: 0, expertise: 1, financial: 2, volunteer_source: 3, store: 4, media: 5 }.freeze
  TIERS = { supporter: 0, partner: 1, maintainer: 2 }.freeze
  STATUSES = { prospect: 0, negotiating: 1, active: 2, paused: 3, ended: 4 }.freeze
  CONFIDENTIAL_RANK = Sensitive::LEVELS.fetch(:confidential)

  belongs_to :ngo
  belongs_to :owner, class_name: "Profile", optional: true, inverse_of: :owned_partnerships
  has_rich_text :terms
  has_many_attached :documents

  enum :kind, KINDS, validate: true, scopes: false
  enum :tier, TIERS, validate: true
  enum :status, STATUSES, validate: true

  scope :publicly_visible, lambda {
    active
      .where("starts_on <= ? AND (ends_on IS NULL OR ends_on >= ?)", Date.current, Date.current)
      .joins(:ngo).merge(Ngo.visible)
  }
  scope :visible, -> { publicly_visible }
  scope :visible_to, ->(context) { publicly_visible.where(sensitivity_level: context.allowed_levels) }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  validates :kind, :tier, :starts_on, :status, :sensitivity_level, presence: true
  validates :ends_on, comparison: { greater_than_or_equal_to: :starts_on }, allow_nil: true
  validate :not_less_restrictive_than_operating_country
  before_validation :inherit_operating_country_sensitivity, on: :create

  def brand_visible?
    active? && starts_on <= Date.current && (ends_on.blank? || ends_on >= Date.current)
  end

  def cash_contributions_cents
    Contribution.confirmed.where(contributor: ngo).sum(:amount_cents)
  end

  def in_kind_donations_cents
    InKindDonation.accepted_for_total.where(donor: ngo).sum(:estimated_value_cents)
  end

  def consolidated_totals
    { cash_cents: cash_contributions_cents, in_kind_cents: in_kind_donations_cents }
  end

  def kind_label
    I18n.t(kind, scope: :partnership_kinds)
  end

  def tier_label
    I18n.t(tier, scope: :partnership_tiers)
  end

  def status_label
    I18n.t(status, scope: :partnership_statuses)
  end

  private

  # Antes da fusão a pergunta atravessava duas tabelas — as bases operadas pela
  # organização —, e agora a ONG É o lugar: o país que interessa é o dela.
  def high_risk_operation?
    ngo&.country&.high_risk?
  end

  def inherit_operating_country_sensitivity
    return unless high_risk_operation? && sensitivity_rank && sensitivity_rank < CONFIDENTIAL_RANK

    self.sensitivity_level = :confidential
  end

  def not_less_restrictive_than_operating_country
    return unless high_risk_operation? && sensitivity_rank && sensitivity_rank < CONFIDENTIAL_RANK

    errors.add(:sensitivity_level, :below_operating_country)
  end

  def sensitivity_rank
    Sensitive::LEVELS[sensitivity_level&.to_sym]
  end
end
