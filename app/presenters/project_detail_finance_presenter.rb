# frozen_string_literal: true

class ProjectDetailFinancePresenter
  BudgetRow = Data.define(:category, :description, :estimated_cents, :spent_cents, :over_budget)
  private_constant :BudgetRow

  def initialize(project, visibility)
    @project = project
    @visibility = visibility
  end

  def funding_value = campaign&.raised_cents || 0
  def funding_target = campaign&.goal_cents || @project.funding_target_cents
  def funding_currency = campaign&.currency || @project.currency

  def budget_rows
    return [] unless budget

    budget.budget_lines.sort_by(&:position).map { |line| BudgetLinePresenter.new(line).row }
  end

  def budget_total_cents = budget&.total_cents.to_i

  private

  def campaign
    @campaign ||= @project.campaigns.visible_to(@visibility).order(created_at: :desc).first
  end

  def budget
    @budget ||= @project.budgets.includes(budget_lines: :expenses).order(version: :desc).first
  end

  class BudgetLinePresenter
    def initialize(line)
      @line = line
    end

    def row
      spent = @line.expenses.reject(&:rejected?).sum(&:amount_cents)
      BudgetRow.new(category: @line.category_label, description: @line.description,
                    estimated_cents: @line.estimated_cents, spent_cents: spent,
                    over_budget: spent > @line.estimated_cents)
    end
  end
end
