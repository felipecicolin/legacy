# frozen_string_literal: true

# Campanha de uma base ou de uma obra. O total em caixa é um cache derivado,
# enquanto o valor de uma doação em espécie fica disponível separadamente.
class Campaign < ApplicationRecord
  include Sensitive
  include ScrubbedPhoto
  include CampaignRules

  STATUSES = { draft: 0, active: 1, paused: 2, reached: 3, closed: 4 }.freeze
  MINIMUM_AGGREGATE_COUNT = 3
  SLUG_SUFFIX_BYTES = 3

  belongs_to :ngo
  belongs_to :project, optional: true
  has_many :contributions, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :nullify
  has_many :in_kind_donations, dependent: :nullify
  has_many :events, dependent: :nullify

  has_rich_text :description
  attaches_scrubbed_photo :cover_image

  enum :status, STATUSES, validate: true

  scope :visible, -> { active.joins(:ngo).merge(Ngo.visible) }
  scope :visible_to, ->(context) { visible.where(sensitivity_level: context.allowed_levels) }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  def self.available_for_support = visible

  def self.for_aggregate = visible

  attr_readonly :slug

  validates :title, :slug, :goal_cents, :currency, :starts_on, :status, :sensitivity_level, presence: true
  validates :slug, uniqueness: true
  validates :goal_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :raised_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  before_validation :assign_slug, on: :create

  def status_label
    I18n.t(status, scope: :campaign_statuses)
  end

  def recalculate_raised_cents
    with_lock { update_column(:raised_cents, cash_raised_cents + in_kind_raised_cents) }
  end
  alias recalculate_raised_cents! recalculate_raised_cents

  def cash_raised_cents
    contributions.confirmed.sum(:amount_cents)
  end

  def in_kind_raised_cents
    in_kind_donations.accepted_for_total.sum(:estimated_value_cents)
  end

  def total_raised_cents = raised_cents

  def progress_percentage
    [(raised_cents * 100 / goal_cents), 100].min
  end

  def accepting_contributions?
    (active? || reached?) && ngo&.ngo_status_active?
  end

  def self.aggregate_by_country(minimum_count: MINIMUM_AGGREGATE_COUNT)
    for_aggregate.group("ngos.country_id")
                 .having("COUNT(campaigns.id) >= ?", minimum_count).sum(:raised_cents)
  end

  class << self
    alias raised_by_country aggregate_by_country
  end

  def visibility_subject = self

  private

  def assign_slug
    self.slug = slug.presence || unique_slug
  end

  def unique_slug
    base = title.to_s.parameterize
    return base unless self.class.exists?(slug: base)

    "#{base}-#{SecureRandom.hex(SLUG_SUFFIX_BYTES)}"
  end
end
