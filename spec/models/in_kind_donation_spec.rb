# frozen_string_literal: true

require "rails_helper"

RSpec.describe InKindDonation do
  let(:campaign) { create(:campaign) }

  describe "accepted donations" do
    let(:donation) { create(:in_kind_donation, campaign:, estimated_value_cents: 4_000) }

    before { donation.accept! }

    it "recalculates the campaign" do
      expect(campaign.reload.raised_cents).to eq(4_000)
    end

    it "counts accepted value" do
      expect(donation.reload).to be_accepted_for_total
    end

    it "records a delivery date" do
      donation.deliver!

      expect(donation.reload.delivered_on).to eq(Date.current)
    end
  end

  it "puts spontaneous offers in triage" do
    donation = create(:in_kind_donation, need_id: nil)

    expect(described_class.in_triage).to include(donation)
  end

  it "labels its category" do
    expect(build(:in_kind_donation, category: :material).category_label).to eq("Material")
  end

  it "records decline reasons" do
    donation = create(:in_kind_donation)
    donation.decline!(reason: "fora do escopo")

    expect(donation.reload.decline_reason).to eq("fora do escopo")
  end

  it "requires positive values and matching currency" do
    invalid = build(:in_kind_donation, campaign:, estimated_value_cents: 0, currency: "USD")

    expect(invalid).not_to be_valid
  end

  it "requires dates and reasons for terminal states" do
    delivered = build(:in_kind_donation, status: :delivered, delivered_on: nil)
    declined = build(:in_kind_donation, status: :declined, decline_reason: nil)

    expect([delivered, declined].map(&:valid?)).to eq([false, false])
  end

  it "requires hours for expertise and services" do
    expertise = build(:in_kind_donation, category: :expertise, unit: "dia")
    service = build(:in_kind_donation, category: :service, unit: "HORA")

    expect(expertise).not_to be_valid
    expect(service).to be_valid
  end
end
