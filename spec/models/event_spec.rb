# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event do
  it "registers free attendees" do
    registration = create(:event).register(profile: create(:profile))

    expect(registration).to be_registered
  end

  it "enforces capacity" do
    event = create(:event, capacity: 1)
    event.register(profile: create(:profile))

    expect { event.register(profile: create(:profile)) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  describe "paid events" do
    let(:event) { create(:event, :paid, campaign: create(:campaign)) }
    let(:registration) { event.register(profile: create(:profile)) }

    it "creates a confirmed contribution" do
      expect(registration.contribution).to be_confirmed
    end

    it "uses the event contribution origin" do
      expect(registration.contribution.origin).to eq("event")
    end

    it "refunds when its registration is cancelled" do
      registration.cancel!

      expect(registration.contribution.reload).to be_refunded
    end

    it "refunds all registrations when cancelled" do
      event.register(profile: create(:profile))
      event.cancel!

      expect(event.reload).to be_cancelled
    end
  end

  it "labels kinds and statuses" do
    event = build(:event, kind: :workshop)

    expect([event.kind_label, event.status_label]).to eq(%w[Oficina Publicado])
  end

  it "keeps a slug immutable" do
    event = create(:event)

    expect { event.update!(slug: "novo") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  it "disambiguates duplicate slugs" do
    first = create(:event, title: "Encontro de apoio")
    second = create(:event, title: "Encontro de apoio")

    expect(second.slug).to start_with("encontro-de-apoio-")
    expect(first.slug).not_to eq(second.slug)
  end

  it "rejects invalid dates, capacity and ticket currency" do
    records = [build(:event, starts_at: 1.day.ago, ends_at: 2.days.ago),
               build(:event, capacity: 0, ticket_price_cents: -1, currency: "reais")]

    expect(records.map(&:valid?)).to eq([false, false])
  end

  it "allows a past event only when held" do
    expect(build(:event, starts_at: 1.day.ago, status: :held)).to be_valid
  end

  it "inherits campaign sensitivity" do
    campaign = create(:campaign, sensitivity_level: :restricted)
    event = build(:event, campaign:, sensitivity_level: :public)

    expect(event.valid? && event.sensitivity_level == "restricted").to be(true)
  end

  it "rejects a less restrictive level when an existing event is changed" do
    campaign = create(:campaign, sensitivity_level: :restricted)
    event = create(:event, campaign:)
    event.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:public))

    expect(event).not_to be_valid
  end

  it "safely resolves a missing campaign rank" do
    event = build(:event, campaign: nil)

    expect(event.send(:campaign_rank)).to be_nil
  end

  it "safely resolves a missing sensitivity rank" do
    event = build(:event, sensitivity_level: nil)

    expect(event.send(:sensitivity_rank)).to be_nil
  end

  it "rejects unavailable campaigns" do
    campaign = create(:campaign, status: :closed)

    expect(build(:event, campaign:)).not_to be_valid
  end
end
