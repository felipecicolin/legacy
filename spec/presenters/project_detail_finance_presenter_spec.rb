# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectDetailFinancePresenter do
  it "uses the visible campaign values and currency when one exists" do
    expect(campaign_values).to eq([12_500, 75_000, "USD"])
  end

  it "reports zero when no budget is published" do
    project = create(:project)
    presenter = described_class.new(project, Visibility::Context.new(clearance: :restricted))

    expect(presenter.budget_total_cents).to eq(0)
  end

  private

  def campaign_values
    project = create(:project, ngo: create(:ngo, :active), funding_target_cents: 50_000)
    create(:campaign, ngo: project.ngo, project:, raised_cents: 12_500, goal_cents: 75_000, currency: "USD")
    presenter = described_class.new(project, Visibility::Context.new(clearance: :restricted))
    [presenter.funding_value, presenter.funding_target, presenter.funding_currency]
  end
end
