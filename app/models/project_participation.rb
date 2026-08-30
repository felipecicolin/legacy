# frozen_string_literal: true

# Papel de uma pessoa dentro de uma obra específica.
class ProjectParticipation < ApplicationRecord
  ROLES = { coordinator: 0, technical_lead: 1, volunteer: 2, local_host: 3, observer: 4 }.freeze
  STATUSES = { invited: 0, active: 1, completed: 2, withdrawn: 3 }.freeze

  belongs_to :project
  belongs_to :profile

  enum :role, ROLES, validate: true
  enum :status, STATUSES, validate: true

  scope :active, -> { where(status: :active) }
  scope :visible_to, ->(context) { where(project_id: Project.visible_to(context).select(:id)) }
  scope :hidden_from, ->(context) { where.not(project_id: Project.visible_to(context).select(:id)) }

  validates :started_on, presence: true
  validates :ended_on, comparison: { greater_than_or_equal_to: :started_on }, allow_nil: true
  validates :role, :status, presence: true
  validates :profile_id, uniqueness: { scope: %i[project_id role] }

  def effective_role
    active? ? role : nil
  end

  def can_submit_progress_report?
    active? && (coordinator? || technical_lead?)
  end

  def visibility_subject = project
end
