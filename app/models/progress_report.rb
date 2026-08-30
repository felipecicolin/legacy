# frozen_string_literal: true

# Log imutável de eventos de avanço físico de uma obra.
class ProgressReport < ApplicationRecord
  include ScrubbedPhoto

  STATUSES = { draft: 0, submitted: 1, approved: 2 }.freeze

  belongs_to :project
  belongs_to :reported_by, class_name: "Profile", inverse_of: :reported_progress_reports
  belongs_to :approved_by, class_name: "Profile", optional: true, inverse_of: :approved_progress_reports

  has_rich_text :summary
  has_rich_text :blockers
  attaches_scrubbed_photos :photos
  has_many :project_photos, dependent: :nullify

  enum :status, STATUSES, validate: true

  # DISTINCT ON é específico do PostgreSQL, banco oficial do projeto, e evita
  # uma consulta por obra para descobrir o relatório mais recente.
  scope :latest_per_project, lambda {
    approved.select("DISTINCT ON (project_id) progress_reports.*")
            .order(:project_id, reported_on: :desc, id: :desc)
  }
  scope :visible_to, ->(context) { approved.where(project_id: Project.visible_to(context).select(:id)) }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  validates :reported_on, :physical_progress, :status, presence: true
  validates :reported_on, comparison: { less_than_or_equal_to: -> { Date.current } }
  validates :physical_progress, numericality: { only_integer: true, in: 0..100 }
  validates :workers_on_site, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :approved_by, :approved_at, presence: true, if: :approved?
  validate :summary_present_when_submitted
  validate :regression_has_explanation

  before_update :refuse_approved_changes
  after_save :refresh_project_progress, if: :approved?

  def submit!
    update!(status: :submitted)
  end

  def submit
    submit!
  rescue ActiveRecord::RecordInvalid
    false
  end

  def approve!(approver:)
    update!(status: :approved, approved_by: approver, approved_at: Time.current)
  end

  def approve(approver:)
    approve!(approver:)
  rescue ActiveRecord::RecordInvalid, Immutable
    false
  end

  def visibility_subject = project

  private

  def summary_present_when_submitted
    return unless submitted? || approved?
    return if summary_present?

    errors.add(:summary, :blank)
  end

  def regression_has_explanation
    return unless progress_regression?
    return if summary_present?

    errors.add(:summary, :regression_explanation_required)
  end

  def progress_regression?
    approved? && physical_progress_changed? && previous_progress.present? && previous_progress > physical_progress
  end

  def previous_progress
    project&.latest_progress_report&.physical_progress
  end

  def refuse_approved_changes
    return unless approved_in_database? && changes_to_save.except("updated_at").present?

    raise Immutable, "progress_report ##{id}"
  end

  def approved_in_database?
    status_in_database == "approved"
  end

  def refresh_project_progress
    project.refresh_physical_progress!
  end

  def summary_present?
    summary.body&.to_plain_text.to_s.strip.present?
  end

  class Immutable < StandardError; end
end
