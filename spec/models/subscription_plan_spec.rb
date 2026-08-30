# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionPlan do
  it "advances a monthly date by one calendar month" do
    expect(build(:subscription_plan, interval: :monthly).next_date(Date.new(2026, 1, 31)))
      .to eq(Date.new(2026, 2, 28))
  end

  it "advances a quarterly date by three calendar months" do
    expect(build(:subscription_plan, interval: :quarterly).next_date(Date.new(2026, 1, 31)))
      .to eq(Date.new(2026, 4, 30))
  end

  it "advances a yearly date by twelve calendar months" do
    expect(build(:subscription_plan, interval: :yearly).next_date(Date.new(2026, 1, 31)))
      .to eq(Date.new(2027, 1, 31))
  end

  it "labels the interval and validates positive cents" do
    expect(build(:subscription_plan, interval: :quarterly).interval_label).to eq("Trimestral")
    expect(build(:subscription_plan, amount_cents: 0)).not_to be_valid
    expect(build(:subscription_plan, currency: "reais")).not_to be_valid
  end
end
