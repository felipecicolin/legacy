# frozen_string_literal: true

module EventRules
  extend ActiveSupport::Concern

  included do
    validate :dates_are_ordered
    validate :past_event_is_held
    validate :campaign_is_available
    validate :not_less_restrictive_than_campaign
    before_validation :assign_slug, on: :create
    before_validation :inherit_campaign_sensitivity, on: :create
  end

  private

  def assign_slug
    self.slug = slug.presence || unique_slug
  end

  def unique_slug
    base = title.to_s.parameterize
    return base unless self.class.exists?(slug: base)

    "#{base}-#{SecureRandom.hex(Event::SLUG_SUFFIX_BYTES)}"
  end

  def active_registration_count
    event_registrations.where.not(status: EventRegistration.statuses.fetch("cancelled")).count
  end

  def dates_are_ordered
    return if ends_at.blank? || starts_at.blank? || ends_at >= starts_at

    errors.add(:ends_at, :after_start)
  end

  def past_event_is_held
    return unless starts_at.present? && starts_at < Time.current && !held?

    errors.add(:starts_at, :past_requires_held)
  end

  def campaign_is_available
    return if campaign.blank? || campaign.accepting_contributions?

    errors.add(:campaign, :not_accepting_contributions)
  end

  def inherit_campaign_sensitivity
    return unless campaign && sensitivity_rank && campaign_rank && sensitivity_rank < campaign_rank

    self.sensitivity_level = campaign.sensitivity_level
  end

  def not_less_restrictive_than_campaign
    return unless campaign && sensitivity_rank && campaign_rank && sensitivity_rank < campaign_rank

    errors.add(:sensitivity_level, :below_campaign)
  end

  def sensitivity_rank
    Sensitive::LEVELS[sensitivity_level&.to_sym]
  end

  def campaign_rank
    Sensitive::LEVELS[campaign&.sensitivity_level&.to_sym]
  end
end
