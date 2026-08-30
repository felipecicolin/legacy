# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription do
  let(:subscription) { create(:subscription, :directed) }

  describe "a successful charge" do
    before { subscription.charge_due! }

    it "increments completed cycles" do
      expect(subscription.reload.cycles_completed).to eq(1)
    end

    it "advances by the plan calendar" do
      expect(subscription.reload.next_charge_on).to eq(subscription.subscription_plan.next_date(Date.current))
    end

    it "creates one confirmed contribution" do
      expect(subscription.contributions).to contain_exactly(be_confirmed)
    end

    it "creates one monthly benefit" do
      expect(subscription.subscriber_benefits.monthly_reports.count).to eq(1)
    end

    it "does not charge a future cycle twice" do
      expect { subscription.charge_due! }.not_to change(Contribution, :count)
    end
  end

  describe "a failed charge" do
    before do
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :refused)
      subscription.charge_due!
    end

    it "moves the subscription to past due" do
      expect(subscription.reload).to be_past_due
    end

    it "schedules a retry for tomorrow" do
      expect(subscription.reload.retry_on).to eq(Date.current + 1.day)
    end

    it "keeps the cycle date and retries the same contribution" do
      date = subscription.next_charge_on
      subscription.update_column(:retry_on, Date.current)
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :succeeded)
      subscription.charge_due!

      expect(subscription.reload.next_charge_on).to eq(subscription.subscription_plan.next_date(date))
    end
  end

  describe "state transitions" do
    before { subscription.pause! }

    it "pauses and resumes" do
      expect(subscription.reload).to be_paused
      expect(subscription.resume!).to be(true)
    end

    it "cancels and preserves a skipped unfinished gift" do
      subscription.resume!
      subscription.cancel!

      expect(subscription.reload).to be_cancelled
      expect(subscription.subscriber_benefits.gifts).to include(have_attributes(status: "skipped"))
    end
  end

  describe "validation" do
    it "rejects an inactive plan" do
      plan = create(:subscription_plan, active: false)

      expect(build(:subscription, subscription_plan: plan)).not_to be_valid
    end

    it "rejects a mismatched campaign currency" do
      expect(build(:subscription, subscription_plan: create(:subscription_plan, currency: "USD"),
                                  campaign: create(:campaign))).not_to be_valid
    end

    it "requires dates in order" do
      expect(build(:subscription, started_on: Date.current,
                                  next_charge_on: Date.current - 1.day)).not_to be_valid
    end
  end

  it "exposes its idempotency key and currency" do
    expect(subscription.idempotency_key).to eq("subscription-#{subscription.id}-#{subscription.next_charge_on}")
    expect(subscription.currency).to eq("BRL")
  end

  it "returns no currency when the plan is absent" do
    invalid = build(:subscription, subscription_plan: nil)

    expect(invalid.currency).to be_nil
  end

  it "rejects a campaign when its plan is absent" do
    invalid = build(:subscription, subscription_plan: nil, campaign: create(:campaign))

    expect(invalid).not_to be_valid
  end

  it "does not create an unearned gift after six completed cycles" do
    completed = create(:subscription, :directed, cycles_completed: 6)

    expect { completed.cancel! }.not_to change(SubscriberBenefit, :count)
  end
end
