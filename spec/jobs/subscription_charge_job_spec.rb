# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionChargeJob do
  it "charges due subscriptions and leaves future subscriptions alone" do
    due = create(:subscription, next_charge_on: Date.current)
    future = create(:subscription, next_charge_on: Date.current + 1.day)

    described_class.perform_now

    expect(due.reload.cycles_completed).to eq(1)
    expect(future.reload.cycles_completed).to eq(0)
  end

  it "keeps the namespaced compatibility job on the same implementation" do
    expect(Subscriptions::ChargeJob).to be < described_class
  end

  describe "past due retries" do
    let(:past_due) { create(:subscription) }

    before do
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :refused)
      past_due.charge_due!
      past_due.update_column(:retry_on, Date.current)
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :succeeded)
    end

    it "returns the subscription to active" do
      described_class.perform_now

      expect(past_due.reload).to be_active
      expect(past_due.cycles_completed).to eq(1)
    end
  end
end
