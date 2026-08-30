# frozen_string_literal: true

class Event < ApplicationRecord
  include Sensitive
  include EventRules

  KINDS = { talk: 0, fundraiser: 1, workshop: 2, campaign_launch: 3 }.freeze
  STATUSES = { draft: 0, published: 1, closed: 2, cancelled: 3, held: 4 }.freeze
  SLUG_SUFFIX_BYTES = 3

  belongs_to :campaign, optional: true
  belongs_to :country, optional: true
  has_many :event_registrations, dependent: :destroy
  has_many :profiles, through: :event_registrations

  enum :kind, KINDS, validate: true
  enum :status, STATUSES, validate: true

  scope :visible, -> { published.where(sensitivity_level: Sensitive::LEVELS.values_at(:public, :restricted)) }
  scope :visible_to, ->(context) { published.where(sensitivity_level: context.allowed_levels) }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  attr_readonly :slug

  validates :title, :slug, :kind, :starts_at, :status, :ticket_price_cents,
            :currency, :sensitivity_level, presence: true
  validates :slug, uniqueness: true
  validates :ticket_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :online, inclusion: { in: [true, false] }

  def register(profile:)
    event_registrations.create!(profile:)
  end

  def cancel
    transaction do
      update!(status: :cancelled)
      event_registrations.find_each(&:cancel!)
    end
  end
  alias cancel! cancel

  def capacity_available?
    capacity.blank? || active_registration_count < capacity
  end

  def kind_label
    I18n.t(kind, scope: :event_kinds)
  end

  def status_label
    I18n.t(status, scope: :event_statuses)
  end

  def visibility_subject = self
end
