# frozen_string_literal: true

require "rails_helper"

RSpec.describe Campaign do
  let(:campaign) { create(:campaign) }

  describe "the funding total" do
    it "starts at zero and exposes a clamped percentage" do
      expect(campaign.total_raised_cents).to eq(0)
      expect(campaign.progress_percentage).to eq(0)
    end

    it "recalculates confirmed cash and accepted in-kind value" do
      create(:contribution, :confirmed, campaign:, amount_cents: 20_000,
                                        provider_reference: "SIM-one")
      create(:in_kind_donation, campaign:, status: :accepted, estimated_value_cents: 5_000)

      expect(campaign.reload.raised_cents).to eq(25_000)
      expect(campaign.cash_raised_cents).to eq(20_000)
      expect(campaign.in_kind_raised_cents).to eq(5_000)
    end

    it "ignores unconfirmed and declined channels" do
      create(:contribution, campaign:, amount_cents: 20_000)
      create(:in_kind_donation, campaign:, status: :declined, estimated_value_cents: 5_000,
                                decline_reason: "duplicado")

      expect(campaign.reload.raised_cents).to eq(0)
    end

    it "caps progress once the goal is reached" do
      campaign.update_column(:raised_cents, campaign.goal_cents * 2)

      expect(campaign.progress_percentage).to eq(100)
    end
  end

  describe "availability" do
    it "accepts active and reached campaigns on active bases" do
      expect(campaign).to be_accepting_contributions

      campaign.update_column(:status, described_class.statuses.fetch("reached"))
      expect(campaign.reload).to be_accepting_contributions
    end

    it "rejects draft, paused and closed campaigns" do
      %w[draft paused closed].each do |status|
        campaign.update_column(:status, described_class.statuses.fetch(status))
        expect(campaign.reload).not_to be_accepting_contributions
      end
    end

    it "rejects a campaign whose base is not active" do
      campaign.mission_base.update!(base_status: :pending)

      expect(campaign.reload).not_to be_accepting_contributions
      expect(described_class.visible).not_to include(campaign)
    end

    it "returns false when its base is absent" do
      expect(build(:campaign, mission_base: nil).accepting_contributions?).to be_nil
    end
  end

  describe "validation and immutability" do
    it "requires a positive goal, a valid currency and ordered dates" do
      invalid = build(:campaign, goal_cents: 0, currency: "reais",
                                 starts_on: Date.current, ends_on: Date.current - 1.day)

      expect(invalid).not_to be_valid
      expect(invalid.errors).to include(:goal_cents, :currency, :ends_on)
    end

    it "keeps a generated slug immutable and disambiguates duplicates" do
      first = create(:campaign, title: "Ajude a escola")
      second = create(:campaign, title: "Ajude a escola")

      expect(first.slug).to eq("ajude-a-escola")
      expect(second.slug).to start_with("ajude-a-escola-")
      expect { first.update!(slug: "outro") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end

    it "rejects a project from another base" do
      expect(build(:campaign, project: create(:project))).not_to be_valid
    end

    it "rejects a less restrictive level when an existing campaign is changed" do
      campaign.mission_base.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:confidential))
      campaign.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:public))

      expect(campaign).not_to be_valid
    end
  end

  describe "visibility and aggregation" do
    let(:aggregate_base) { create(:mission_base, :active) }
    let(:aggregate_campaigns) { create_list(:campaign, 3, mission_base: aggregate_base) }
    let(:aggregate_total) do
      aggregate_campaigns.each_with_index { |record, index| record.update_column(:raised_cents, (index + 1) * 100) }
      described_class.aggregate_by_country
    end

    it "filters by context and keeps only anonymous country totals" do
      expect(aggregate_total).to eq(aggregate_base.country_id => 600)
      expect(described_class.raised_by_country).to eq(aggregate_base.country_id => 600)
      restricted = Visibility::Context.new(clearance: :restricted)
      expect(described_class.visible_to(restricted)).to include(campaign)
      expect(described_class.hidden_from(restricted)).not_to include(campaign)
    end

    it "does not aggregate fewer than the configured minimum" do
      base = create(:mission_base, :active)
      create_list(:campaign, 2, mission_base: base).each { |record| record.update_column(:raised_cents, 0) }

      expect(described_class.aggregate_by_country).to be_empty
      expect(described_class.aggregate_by_country(minimum_count: 2)).to eq(base.country_id => 0)
    end
  end

  describe "sensitivity" do
    it "inherits a confidential base and rejects an explicit open level" do
      base = create(:mission_base, country: create(:country, high_risk: true), base_status: :active)
      records = [build(:campaign, mission_base: base), build(:campaign, mission_base: base, sensitivity_level: :public)]

      expect(records.map(&:valid?)).to eq([true, true])
      expect(records).to all(be_confidential)
    end

    it "does not blow up when a level or base is absent" do
      expect(build(:campaign, mission_base: nil)).not_to be_valid
      invalid = build(:campaign).tap { |record| record.sensitivity_level = "secret" }
      missing_level = build(:campaign, sensitivity_level: nil)

      expect { invalid.valid? }.not_to raise_error
      expect { missing_level.valid? }.not_to raise_error
    end
  end

  it "labels its status" do
    expect(build(:campaign, status: :active).status_label).to eq("Ativa")
  end
end
