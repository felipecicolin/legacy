# frozen_string_literal: true

class BudgetLine < ApplicationRecord
  CATEGORIES = { material: 0, labor: 1, equipment: 2, logistics: 3, permits: 4, contingency: 5 }.freeze

  belongs_to :budget
  belongs_to :project_phase, optional: true, inverse_of: :budget_lines
  has_many :expenses, dependent: :nullify

  enum :category, CATEGORIES, validate: true

  before_save :forbid_approved_change

  validates :description, :estimated_cents, :category, presence: true
  validates :estimated_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :budget_is_editable

  after_destroy :refresh_budget
  after_save :refresh_budget

  def spent_cents
    expenses.where.not(status: Expense.statuses.fetch("rejected")).sum(:amount_cents)
  end

  def over_budget?
    spent_cents > estimated_cents
  end

  def category_label
    I18n.t(category, scope: :budget_categories)
  end

  def revision_attributes
    attributes.slice("category", "description", "estimated_cents", "position")
  end

  private

  def refresh_budget
    budget.recalculate_total_cents!
  end

  def budget_is_editable
    return if budget.blank? || !budget.approved?

    errors.add(:budget, :immutable)
  end

  def forbid_approved_change
    return unless budget&.approved?

    raise Budget::Immutable, I18n.t("budgets.immutable")
  end
end
