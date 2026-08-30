# frozen_string_literal: true

require "rails_helper"

RSpec.describe FundraisingDashboard do
  let(:admin) { create(:user) }
  let(:context) do
    create(:staff_role, :admin, user: admin)
    Authorization::Context.for(admin)
  end
  let(:campaign) { create(:campaign) }

  it "sums the four cash channels to the cent" do
    seed_cash_channels

    expect(described_class.new(context).cash_total_cents).to eq(100_000)
  end

  it "keeps estimated in-kind value out of the cash total" do
    seed_cash_and_in_kind
    dashboard = described_class.new(context)

    expect([dashboard.cash_total_cents, dashboard.in_kind_total_cents]).to eq([10_000, 75_000])
  end

  it "normalizes active and past due subscriptions into monthly revenue" do
    seed_subscriptions

    expect(described_class.new(context).subscriptions.monthly_recurring_cents).to eq(4_000)
  end

  it "groups the monthly series by all four channels" do
    seed_trend
    points = described_class.new(context).trend.points

    expect(points.last.amounts).to include(one_off: 1_000, event_store: 2_000, in_kind: 3_000, recurring: 0)
  end

  private

  def seed_cash_channels
    profile = create(:profile)
    subscription = create(:subscription, subscriber: profile)
    [[:one_off, 10_000], [:subscription, 20_000], [:event, 30_000], [:store, 40_000]].each do |origin, cents|
      create(:contribution, :confirmed, campaign:, contributor: profile, amount_cents: cents, origin:, subscription:)
    end
  end

  def seed_cash_and_in_kind
    profile = create(:profile)
    create(:contribution, :confirmed, campaign:, contributor: profile, amount_cents: 10_000)
    create(:in_kind_donation, campaign:, status: :accepted, estimated_value_cents: 75_000)
  end

  def seed_subscriptions
    create(:subscription, status: :active,
                          subscription_plan: create(:subscription_plan, amount_cents: 12_000, interval: :yearly))
    create(:subscription, status: :past_due,
                          subscription_plan: create(:subscription_plan, amount_cents: 9_000, interval: :quarterly))
    create(:subscription, status: :cancelled,
                          subscription_plan: create(:subscription_plan, amount_cents: 50_000, interval: :monthly))
  end

  def seed_trend
    travel_to Date.new(2026, 8, 30) do
      create(:contribution, :confirmed, campaign:, origin: :one_off, amount_cents: 1_000)
      create(:contribution, :confirmed, campaign:, origin: :event, amount_cents: 2_000)
      create(:in_kind_donation, campaign:, status: :accepted, estimated_value_cents: 3_000)
    end
  end
end
