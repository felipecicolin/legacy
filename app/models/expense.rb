# frozen_string_literal: true

class Expense < ApplicationRecord
  include Sensitive
  include ScrubbedPhoto

  STATUSES = { recorded: 0, approved: 1, rejected: 2 }.freeze
  CATEGORIES = BudgetLine::CATEGORIES

  belongs_to :project
  belongs_to :budget_line, optional: true
  belongs_to :recorded_by, class_name: "Profile", inverse_of: :recorded_expenses
  attaches_scrubbed_photo :receipt

  enum :status, STATUSES, validate: true
  enum :category, CATEGORIES, validate: true

  attr_readonly :simulated

  validates :amount_cents, :currency, :incurred_on, :category, :status, :sensitivity_level, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :simulated, inclusion: { in: [true, false] }
  validate :currency_matches_project
  validate :budget_line_belongs_to_project
  validate :not_less_restrictive_than_project
  before_validation :inherit_project_sensitivity, on: :create

  def over_budget?
    budget_line.present? && projected_spent_cents > budget_line.estimated_cents
  end

  def budget_variance_cents
    return 0 unless budget_line

    projected_spent_cents - budget_line.estimated_cents
  end

  def visibility_subject = project

  private

  def inherit_project_sensitivity
    return unless project && sensitivity_rank && project_rank && sensitivity_rank < project_rank

    self.sensitivity_level = project.sensitivity_level
  end

  def not_less_restrictive_than_project
    return unless project && sensitivity_rank && project_rank && sensitivity_rank < project_rank

    errors.add(:sensitivity_level, :below_project)
  end

  def sensitivity_rank
    Sensitive::LEVELS[sensitivity_level&.to_sym]
  end

  def project_rank
    Sensitive::LEVELS[project&.sensitivity_level&.to_sym]
  end

  def currency_matches_project
    return if project.blank? || currency == project.currency

    errors.add(:currency, :currency_mismatch)
  end

  def budget_line_belongs_to_project
    return if budget_line.blank? || budget_line.budget.project_id == project_id

    errors.add(:budget_line, :wrong_project)
  end

  def projected_spent_cents
    spent = budget_line.spent_cents
    return spent + amount_cents.to_i if new_record?

    spent - amount_cents_in_budget_line + amount_cents.to_i
  end

  def amount_cents_in_budget_line
    budget_line.expenses.where(id:).pick(:amount_cents).to_i
  end
end
