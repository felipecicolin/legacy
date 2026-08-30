# frozen_string_literal: true

require "rails_helper"

RSpec.describe Expense do
  let(:project) { create(:project) }

  it "keeps money in cents and reports budget variance without rejecting overspend" do
    line = create(:budget_line, budget: create(:budget, project:), estimated_cents: 1_000)
    expense = create(:expense, project:, budget_line: line, amount_cents: 1_500)

    expect(expense).to be_over_budget
    expect(expense.budget_variance_cents).to eq(500)
    expect(expense.reload).to be_simulated
  end

  it "does not count rejected expenses or double-count itself" do
    line = create(:budget_line, budget: create(:budget, project:), estimated_cents: 1_000)
    expense = create(:expense, project:, budget_line: line, amount_cents: 700)

    expect(expense.reload.budget_variance_cents).to eq(-300)
    create(:expense, project:, budget_line: line, amount_cents: 700, status: :rejected)
    expect(expense.reload.budget_variance_cents).to eq(-300)
  end

  it "returns zero variance without a budget line" do
    expect(build(:expense, budget_line: nil).budget_variance_cents).to eq(0)
  end

  it "rejects mismatched currency and a budget line from another project" do
    foreign_line = create(:budget_line)
    invalid = build(:expense, project:, budget_line: foreign_line, currency: "USD")

    expect(invalid).not_to be_valid
  end

  it "inherits the most restrictive project level" do
    project.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:confidential))
    expense = build(:expense, project:, sensitivity_level: :public)

    expect(expense).to be_valid
    expect(expense.sensitivity_level).to eq("confidential")
  end

  it "rejects a less restrictive level when an existing expense is changed" do
    project.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:confidential))
    expense = create(:expense, project:)
    expense.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:public))

    expect(expense).not_to be_valid
  end

  it "safely resolves a missing project rank" do
    expense = build(:expense, project: nil)

    expect(expense.send(:project_rank)).to be_nil
  end

  it "safely resolves a missing sensitivity rank" do
    expect(build(:expense, sensitivity_level: nil).send(:sensitivity_rank)).to be_nil
  end

  it "projects the amount for an unsaved expense" do
    line = create(:budget_line, estimated_cents: 1_000)
    expense = build(:expense, project: line.budget.project, budget_line: line, amount_cents: 1_100)

    expect(expense).to be_over_budget
  end

  it "refuses invalid money, simulation stamps and categories" do
    invalid = build(:expense, project:, amount_cents: 0, currency: "reais")

    expect(invalid).not_to be_valid
    saved = create(:expense, project:)
    expect { saved.update!(simulated: false) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end
end
