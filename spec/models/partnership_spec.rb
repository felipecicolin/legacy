# frozen_string_literal: true

require "rails_helper"

RSpec.describe Partnership do
  let(:organization) { create(:organization, organization_status: :approved) }
  let(:partnership) { create(:partnership, organization:) }

  it "publishes active current partnerships" do
    expect(described_class.publicly_visible).to include(partnership)
  end

  it "shows the current brand" do
    expect(partnership).to be_brand_visible
  end

  it "removes an expired brand" do
    partnership.update_column(:ends_on, Date.current - 1.day)

    expect(described_class.publicly_visible).not_to include(partnership)
  end

  it "hides brands for pending organizations" do
    expect(described_class.visible_to(Visibility::Context.anonymous)).not_to include(create(:partnership))
  end

  it "keeps cash and in-kind totals separate" do
    create(:contribution, :confirmed, contributor: organization, provider_reference: "SIM-partner")
    create(:in_kind_donation, donor: organization, status: :accepted, estimated_value_cents: 3_000)

    expect(partnership.consolidated_totals).to eq(cash_cents: 25_000, in_kind_cents: 3_000)
  end

  it "labels kind, tier and status" do
    labels = partnership.attributes.slice("kind", "tier", "status").keys.map do |name|
      partnership.public_send("#{name}_label")
    end

    expect(labels).to eq(%w[Financeira Apoiadora Ativa])
  end

  it "inherits confidential sensitivity from a high-risk country" do
    organization.mission_bases.create!(country: create(:country, high_risk: true), name: "Base de risco",
                                       base_kind: :mission_base)
    partnership = build(:partnership, organization:, sensitivity_level: :public)

    expect(partnership.valid? && partnership.confidential?).to be(true)
  end

  it "rejects a less restrictive level when an existing partnership is changed" do
    organization.mission_bases.create!(country: create(:country, high_risk: true), name: "Base de risco",
                                       base_kind: :mission_base)
    partnership = create(:partnership, organization:)
    partnership.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:public))

    expect(partnership).not_to be_valid
  end

  it "safely resolves a missing sensitivity level" do
    partnership = build(:partnership, sensitivity_level: nil)

    expect(partnership.send(:sensitivity_rank)).to be_nil
  end

  it "rejects invalid dates and absent organizations" do
    invalid = build(:partnership, starts_on: Date.current, ends_on: Date.current - 1.day)
    missing = build(:partnership, organization: nil)

    expect([invalid, missing].map(&:valid?)).to eq([false, false])
  end
end
