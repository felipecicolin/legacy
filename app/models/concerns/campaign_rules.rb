# frozen_string_literal: true

module CampaignRules
  extend ActiveSupport::Concern

  included do
    validate :dates_are_ordered
    validate :project_belongs_to_base
    validate :not_less_restrictive_than_base
    before_validation :inherit_base_sensitivity, on: :create
  end

  private

  def dates_are_ordered
    return if ends_on.blank? || starts_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, :after_start)
  end

  def project_belongs_to_base
    return if project.blank? || project.mission_base_id == mission_base_id

    errors.add(:project, :wrong_mission_base)
  end

  def inherit_base_sensitivity
    return unless mission_base && own_rank && own_rank < base_rank

    self.sensitivity_level = mission_base.sensitivity_level
  end

  def not_less_restrictive_than_base
    return unless mission_base && own_rank && own_rank < base_rank

    errors.add(:sensitivity_level, :below_mission_base)
  end

  def base_rank = Sensitive::LEVELS.fetch(mission_base.sensitivity_level.to_sym)

  def own_rank = Sensitive::LEVELS[sensitivity_level&.to_sym]
end
