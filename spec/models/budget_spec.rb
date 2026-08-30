# frozen_string_literal: true

require "rails_helper"

RSpec.describe Budget do
  let(:project) { create(:project) }

  describe "derived totals" do
    let(:budget) { create(:budget, project:) }
    let!(:line) { create(:budget_line, budget:, estimated_cents: 12_000) }

    it "sums editable lines" do
      expect(budget.reload.total_cents).to eq(12_000)
    end

    it "updates after a line is removed" do
      line.destroy!

      expect(budget.reload.total_cents).to eq(0)
    end

    it "approves a draft" do
      expect(budget.approve!).to be(true)
      expect(budget.reload).to be_approved
    end

    it "reports whether the budget is immutable" do
      expect(budget).not_to be_immutable
      budget.approve!

      expect(budget.reload).to be_immutable
    end
  end

  describe "approved revisions" do
    let(:budget) { create(:budget, project:) }

    before do
      create(:budget_line, budget:, category: :labor, description: "Equipe", estimated_cents: 9_000)
      budget.approve!
    end

    it "refuses direct changes" do
      expect { budget.update!(total_cents: 1) }.to raise_error(Budget::Immutable)
    end

    it "copies lines into a new draft version" do
      revision = budget.revise!

      expect(revision.budget_lines.pluck(:description)).to eq(["Equipe"])
    end

    it "increments the revision version and total" do
      revision = budget.revise!

      expect([revision.version, revision.total_cents]).to eq([2, 9_000])
    end
  end

  it "validates positive totals, versions and project currency" do
    invalid = build(:budget, project:, total_cents: -1, version: 0, currency: "USD")

    expect(invalid).not_to be_valid
  end
end
