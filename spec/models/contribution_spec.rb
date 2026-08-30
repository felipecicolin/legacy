# frozen_string_literal: true

require "rails_helper"

RSpec.describe Contribution do
  let(:campaign) { create(:campaign) }

  describe "the simulated payment" do
    describe "a successful outcome" do
      let(:successful) { create(:contribution, campaign:) }

      before { successful.process! }

      it "confirms the contribution" do
        expect(successful.reload).to be_confirmed
      end

      it "stores the provider reference" do
        expect(successful.reload.provider_reference).to start_with("SIM-")
      end

      it "issues an attached receipt" do
        expect(successful.reload.receipt.pdf).to be_attached
      end

      it "records the gateway transaction" do
        expect(PaymentTransaction.where(reference: "contribution-#{successful.id}")).to exist
      end
    end

    it "keeps a pending outcome pending" do
      pending = create(:contribution, campaign:)
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :pending)
      pending.process!

      expect(pending.reload).to be_pending
    end

    it "maps a refusal to failed and excludes it from totals" do
      failed = create(:contribution, campaign:)
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :refused)
      failed.process!

      expect(failed.reload).to be_failed
      expect(campaign.reload.raised_cents).to eq(0)
    end

    it "refunds a confirmed contribution through the gateway" do
      contribution = create(:contribution, :confirmed, campaign:, provider_reference: "SIM-refund")

      result = contribution.refund!

      expect(result.status).to eq("succeeded")
      expect(contribution.reload).to be_refunded
      expect(PaymentTransaction.where(kind: :refund)).to exist
    end

    it "does not mark a contribution refunded when the provider refuses" do
      contribution = create(:contribution, :confirmed, campaign:, provider_reference: "SIM-refused-refund")
      Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: :refused)

      expect(contribution.refund!.status).to eq("refused")
      expect(contribution.reload).to be_confirmed
    end

    it "confirms a pending contribution directly" do
      contribution = create(:contribution, campaign:)

      expect(contribution.confirm!).to be(true)
      expect(contribution.reload).to be_confirmed
    end
  end

  describe "invariants" do
    it "requires a campaign for non-subscription origins" do
      contribution = build(:contribution, campaign: nil, origin: :one_off)

      expect(contribution).not_to be_valid
      expect(contribution.errors[:campaign]).to be_present
    end

    it "allows general subscription contributions without a campaign" do
      contribution = build(:contribution, campaign: nil, origin: :subscription,
                                          subscription: build(:subscription))

      expect(contribution).to be_valid
    end

    it "requires a subscription for subscription-origin contributions" do
      expect(build(:contribution, campaign: nil, origin: :subscription)).not_to be_valid
    end

    it "enforces campaign status and currency" do
      campaign.update_column(:status, Campaign.statuses.fetch("closed"))
      closed = build(:contribution, campaign:)
      mismatched = build(:contribution, campaign:, currency: "USD")

      expect(closed).not_to be_valid
      expect(mismatched).not_to be_valid
    end

    it "requires a positive integer amount" do
      expect(build(:contribution, campaign:, amount_cents: 0)).not_to be_valid
    end

    it "tracks simulation origin" do
      expect(build(:contribution, campaign:).simulated).to be(true)
    end

    it "hides a named contributor from an anonymous context" do
      contributor = create(:profile)
      named = create(:contribution, :confirmed, campaign:, contributor:, provider_reference: "SIM-named")
      outsider = Visibility::Context.anonymous

      expect(named.public_contributor(context: outsider)).to be_nil
    end

    it "reveals a named contributor to an authorized context" do
      contributor = create(:profile)
      named = create(:contribution, :confirmed, campaign:, contributor:, provider_reference: "SIM-visible")
      context = Visibility::Context.new(clearance: :restricted)

      expect(named.public_contributor(context:)).to eq(contributor)
    end

    it "hides an anonymous contributor from every context" do
      contributor = create(:profile)
      anonymous = create(:contribution, :confirmed, campaign:, contributor:, anonymous: true,
                                                    provider_reference: "SIM-anonymous")
      outsider = Visibility::Context.anonymous

      expect(anonymous.public_contributor(context: outsider)).to be_nil
    end

    it "keeps the campaign as its visibility subject" do
      expect(build(:contribution, campaign:).visibility_subject).to eq(campaign)
    end
  end

  it "does not allow the simulated stamp to be promoted" do
    contribution = create(:contribution, campaign:)

    expect { contribution.update!(simulated: false) }
      .to raise_error(ActiveRecord::ReadonlyAttributeError)
  end
end
