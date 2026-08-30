# frozen_string_literal: true

class Budget < ApplicationRecord
  STATUSES = { draft: 0, approved: 1, revised: 2 }.freeze

  class Immutable < StandardError; end

  belongs_to :project
  has_many :budget_lines, dependent: :destroy

  enum :status, STATUSES, validate: true

  validates :currency, :status, :version, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :version, uniqueness: { scope: :project_id }
  validate :currency_matches_project
  before_update :refuse_approved_changes

  def recalculate_total_cents
    with_lock { update_column(:total_cents, budget_lines.sum(:estimated_cents)) }
  end
  alias recalculate_total_cents! recalculate_total_cents

  def approve
    update!(status: :approved)
  end
  alias approve! approve

  def revise(attributes = {})
    self.class.transaction { copy_as_revision(attributes) }
  end
  alias revise! revise

  def immutable?
    approved?
  end

  private

  def copy_as_revision(attributes)
    revision = self.class.create!(project:, currency:, version: version + 1, status: :draft, **attributes)
    budget_lines.find_each { |line| revision.budget_lines.create!(line.revision_attributes) }
    revision.recalculate_total_cents!
    revision
  end

  def currency_matches_project
    return if project.blank? || currency == project.currency

    errors.add(:currency, :currency_mismatch)
  end

  def refuse_approved_changes
    return unless status_was == "approved" && changes_to_save.except("updated_at").present?

    raise Immutable, I18n.t("budgets.immutable")
  end
end
