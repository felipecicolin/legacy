# frozen_string_literal: true

# Levantamento de campo como entregável, e não apenas como estado da obra.
class SiteSurvey < ApplicationRecord
  STATUSES = { draft: 0, submitted: 1 }.freeze

  belongs_to :project
  belongs_to :surveyed_by, class_name: "Profile", inverse_of: :surveyed_site_surveys

  has_rich_text :findings
  has_rich_text :recommendations
  has_many_attached :documents

  enum :status, STATUSES, validate: true

  validates :surveyed_on, :currency, :status, presence: true
  validates :surveyed_on, comparison: { less_than_or_equal_to: -> { Date.current } }
  validates :estimated_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, length: { maximum: 3 }, format: { with: /\A[A-Z]{3}\z/ }
  validate :findings_present_when_submitted

  scope :latest, -> { order(surveyed_on: :desc, id: :desc) }
  scope :visible_to, ->(context) { submitted.where(project_id: Project.visible_to(context).select(:id)) }
  scope :hidden_from, ->(context) { where.not(id: visible_to(context).select(:id)) }

  def submit!
    update!(status: :submitted)
  end

  def submit
    submit!
  rescue ActiveRecord::RecordInvalid
    false
  end

  def visibility_subject = project

  private

  def findings_present_when_submitted
    return unless submitted?
    return if findings_present?

    errors.add(:findings, :blank)
  end

  def findings_present?
    findings.body&.to_plain_text.to_s.strip.present?
  end
end
