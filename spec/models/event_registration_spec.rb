# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventRegistration do
  it "rejects registration for a draft event" do
    registration = build(:event_registration, event: build(:event, status: :draft))

    expect(registration).not_to be_valid
  end

  it "confirms a free registration" do
    registration = create(:event_registration)

    expect(registration.confirm!).to be(true)
  end

  it "cancels a free registration without a contribution" do
    registration = create(:event_registration)
    registration.cancel!

    expect(registration.reload).to be_cancelled
    expect(registration.contribution).to be_nil
  end

  it "requires a campaign for a paid event" do
    event = build(:event, :paid, campaign: nil)

    expect(build(:event_registration, event:)).not_to be_valid
  end

  it "prevents duplicate profiles" do
    paid = create(:event, :paid, campaign: create(:campaign))
    profile = create(:profile)
    create(:event_registration, event: paid, profile:)
    duplicate = build(:event_registration, event: paid, profile:)

    expect(duplicate).not_to be_valid
  end

  it "keeps a registration registered when a paid charge fails" do
    event = create(:event, :paid, campaign: create(:campaign))
    Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :refused)

    registration = event.register(profile: create(:profile))

    expect(registration).to be_registered
    expect(registration.contribution).to be_failed
  end
end
