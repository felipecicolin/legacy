# frozen_string_literal: true

# Obra episódica ligada a uma base durável, com trilha de avanço própria.
class Project < ApplicationRecord
  include Sensitive

  STATUSES = { surveying: 0, in_progress: 1, paused: 2, urgent: 3, completed: 4 }.freeze
  TRANSITIONS = {
    "surveying" => %w[in_progress paused],
    "in_progress" => %w[paused urgent completed],
    "paused" => %w[in_progress urgent],
    "urgent" => %w[in_progress paused completed],
    "completed" => [],
  }.freeze

  belongs_to :mission_base
  delegate :country_label, :region_label, to: :mission_base, allow_nil: true
  has_many :site_surveys, dependent: :destroy
  has_many :progress_reports, dependent: :destroy
  has_many :project_participations, dependent: :destroy
  has_many :profiles, through: :project_participations
  has_many :project_photos, dependent: :destroy

  has_rich_text :scope_description

  enum :status, STATUSES, validate: true

  scope :visible_to, lambda { |context|
    joins(:mission_base).merge(MissionBase.visible)
                        .where(projects: { sensitivity_level: context.allowed_levels })
  }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  attr_readonly :code

  validates :code, :title, :currency, :status, :sensitivity_level, presence: true
  validates :code, uniqueness: true, format: { with: /\AOB-\d{4,}\z/ }
  validates :funding_target_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :physical_progress, numericality: { only_integer: true, in: 0..100 }
  validates :currency, length: { maximum: 3 }, format: { with: /\A[A-Z]{3}\z/ }
  validate :sensitivity_not_less_than_base
  validate :dates_are_ordered
  validate :valid_status_transition, on: :update
  validate :coordinator_for_start, on: :update

  before_validation :assign_code, on: :create
  before_validation :inherit_base_sensitivity, on: :create

  def transition_to!(target)
    target = target.to_s
    raise ArgumentError, "invalid project status transition" unless transition_allowed?(target)

    update!(status: target)
  end

  def transition_allowed?(target)
    TRANSITIONS.fetch(status, []).include?(target.to_s)
  end

  def active_coordinator?
    project_participations.active.exists?(role: :coordinator)
  end

  def latest_progress_report
    progress_reports.approved.order(reported_on: :desc, id: :desc).first
  end

  def refresh_physical_progress!
    report = latest_progress_report
    update_column(:physical_progress, report&.physical_progress || 0)
  end

  def refresh_physical_progress
    refresh_physical_progress!
  end

  def transition_to(target)
    transition_to!(target)
  rescue ArgumentError, ActiveRecord::RecordInvalid
    false
  end

  def visibility_subject = self

  private

  def assign_code
    return if code.present?

    value = self.class.connection.select_value("select nextval('projects_id_seq')")
    self.code = format("OB-%04d", value)
  end

  def inherit_base_sensitivity
    return unless mission_base && default_sensitivity_requested?

    self.sensitivity_level = mission_base.sensitivity_level
  end

  def default_sensitivity_requested?
    sensitivity_level_before_type_cast.to_s == Sensitive::DEFAULT_LEVEL.to_s
  end

  def sensitivity_not_less_than_base
    return if mission_base.blank? || sensitivity_level.blank?

    current = Sensitive.sensitivity_rank(sensitivity_level)
    base = Sensitive.sensitivity_rank(mission_base.sensitivity_level)
    return if current >= base

    errors.add(:sensitivity_level, :less_restrictive_than_base)
  end

  def dates_are_ordered
    [[:planned_end_on, planned_start_on, planned_end_on],
     [:actual_end_on, actual_start_on, actual_end_on]].each do |attribute, start_on, end_on|
      next unless start_on.present? && end_on.present? && end_on < start_on

      errors.add(attribute, :after_start)
    end
  end

  def valid_status_transition
    return unless status_changed?

    allowed = TRANSITIONS.fetch(status_was.to_s, [])
    errors.add(:status, :invalid_transition) unless allowed.include?(status.to_s)
  end

  def coordinator_for_start
    return unless status_changed? && in_progress? && !active_coordinator?

    errors.add(:base, :coordinator_required)
  end
end
