# frozen_string_literal: true

# Lugar durável que pode acumular várias obras e necessidades ao longo dos anos.
class MissionBase < ApplicationRecord
  include Sensitive
  include ScrubbedPhoto

  KINDS = { mission_base: 0, ngo: 1, school: 2, housing: 3, church: 4, clinic: 5 }.freeze
  STATUSES = { pending: 0, active: 1, inactive: 2 }.freeze
  SLUG_SUFFIX_BYTES = 3

  belongs_to :country
  belongs_to :region, optional: true
  belongs_to :organization, optional: true
  has_many :projects, dependent: :restrict_with_error

  has_rich_text :description
  attaches_scrubbed_photo :cover_image

  enum :kind, KINDS, validate: true
  enum :status, STATUSES, validate: true

  scope :visible, -> { active }
  scope :available_for_support, -> { visible }
  scope :visible_to, ->(context) { visible.where(sensitivity_level: context.allowed_levels) }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  attr_readonly :slug

  validates :name, :slug, :kind, :status, :sensitivity_level, presence: true
  validates :slug, uniqueness: true
  validates :people_served, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validate :region_belongs_to_country

  before_validation :inherit_country_sensitivity
  before_validation :assign_slug, on: :create

  def kind_label
    I18n.t(kind, scope: :kinds)
  end

  def status_label
    I18n.t(status, scope: :statuses)
  end

  def country_label
    country&.name
  end

  def region_label
    region&.name
  end

  def to_s = name

  private

  def inherit_country_sensitivity
    return unless new_record? && country
    return unless country.high_risk? || default_sensitivity_requested?

    self.sensitivity_level = country.default_sensitivity
  end

  def default_sensitivity_requested?
    sensitivity_level_before_type_cast.to_s == Sensitive::DEFAULT_LEVEL.to_s
  end

  def assign_slug
    self.slug = slug.presence || unique_slug
  end

  def unique_slug
    base = name.to_s.parameterize
    return base unless self.class.exists?(slug: base)

    "#{base}-#{SecureRandom.hex(SLUG_SUFFIX_BYTES)}"
  end

  def region_belongs_to_country
    return if region.blank? || country.blank? || region.country_id == country_id

    errors.add(:region, :invalid)
  end
end
