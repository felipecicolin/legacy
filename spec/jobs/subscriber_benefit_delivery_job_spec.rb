# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriberBenefitDeliveryJob do
  describe "a due report" do
    let!(:benefit) { create(:subscriber_benefit, due_on: Date.current) }

    before { described_class.perform_now }

    it "prepares and delivers it" do
      expect(benefit.reload).to be_delivered
    end

    it "emails the subscriber" do
      expect(ActionMailer::Base.deliveries.last.to).to include(benefit.delivery_address)
    end
  end

  it "delivers without email for a subscriber without a user" do
    benefit = create(:subscriber_benefit, subscription: create(:subscription, subscriber: create(:ngo)),
                                          due_on: Date.current)

    expect { described_class.perform_now }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(benefit.reload).to be_delivered
  end
end
