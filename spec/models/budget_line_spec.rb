# frozen_string_literal: true

require "rails_helper"

RSpec.describe BudgetLine do
  describe "spending" do
    let(:line) { create(:budget_line, estimated_cents: 1_000) }
    let(:project) { line.budget.project }

    it "counts non-rejected expenses" do
      create(:expense, project:, budget_line: line, amount_cents: 700)
      create(:expense, project:, budget_line: line, amount_cents: 700, status: :rejected)

      expect(line.spent_cents).to eq(700)
    end

    it "signals overspend" do
      create(:expense, project:, budget_line: line, amount_cents: 1_100)

      expect(line.reload).to be_over_budget
    end
  end

  it "labels its category" do
    expect(build(:budget_line, category: :material).category_label).to eq("Material")
  end

  it "refuses edits when its budget is approved" do
    line = create(:budget_line)
    line.budget.approve!
    line.description = "alterada"

    expect(line).not_to be_valid
    expect { line.save!(validate: false) }.to raise_error(Budget::Immutable)
  end

  it "safely ignores an absent budget in the immutable callback" do
    line = build(:budget_line, budget: nil)

    expect { line.send(:forbid_approved_change) }.not_to raise_error
  end

  it "validates non-negative estimates and positions" do
    expect(build(:budget_line, estimated_cents: -1, position: -1)).not_to be_valid
  end
end
