# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriberBenefit do
  let(:subscription) { create(:subscription, :directed) }

  describe "sixth-cycle benefits" do
    before do
      subscription.update!(cycles_completed: 6)
      described_class.create_for_cycle!(subscription, Date.current)
    end

    it "creates a monthly report" do
      expect(subscription.subscriber_benefits.monthly_reports.count).to eq(1)
    end

    it "creates one semiannual gift" do
      expect(subscription.subscriber_benefits.gifts.count).to eq(1)
    end
  end

  describe "monthly reports" do
    let(:benefit) { create(:subscriber_benefit, subscription:) }
    let(:restricted_context) { Visibility::Context.new(clearance: :restricted) }

    it "honestly reports that the period has no update" do
      expect(benefit.report_body(context: restricted_context))
        .to eq("Não houve relatório aprovado neste período.")
    end

    it "prepares content" do
      benefit.prepare!(context: restricted_context)

      expect(benefit.reload).to be_prepared
    end

    it "delivers prepared content" do
      benefit.prepare!(context: restricted_context)
      benefit.deliver!

      expect(benefit.reload).to be_delivered
    end
  end

  it "includes the approved report from the benefit period" do
    campaign = create(:campaign, :with_project)
    report = create(:progress_report, :approved, project: campaign.project, reported_on: Date.current)
    benefit = create(:subscriber_benefit, subscription: create(:subscription, campaign:))

    expect(benefit.report_body(context: Visibility::Context.new(clearance: :restricted)))
      .to include(report.physical_progress.to_s)
  end

  it "restricts an inaccessible campaign report" do
    benefit = create(:subscriber_benefit, subscription:)
    context = instance_double(Visibility::Context, can_identify?: false)

    expect(benefit.report_body(context:)).to eq("O andamento desta obra não está disponível para este acesso.")
  end

  describe "gifts and skips" do
    let(:gift) { build(:subscriber_benefit, subscription:, kind: :semiannual_gift) }

    it "uses the gift message" do
      expect(gift.report_body).to eq("Benefício semestral em preparação.")
    end

    it "requires content when prepared" do
      expect { gift.update!(status: :prepared) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "records a skip reason" do
      gift.save!
      gift.skip!(reason: "cancelled")

      expect(gift.reload.skipped_reason).to eq("cancelled")
    end

    it "skips an unearned gift on cancellation" do
      described_class.skip_gift_for!(subscription, "cancelled")

      expect(subscription.subscriber_benefits.gifts).to include(have_attributes(status: "skipped"))
    end
  end

  it "returns no address when the subscriber has no user" do
    subscription = build(:subscription, subscriber: build(:ngo))

    expect(build(:subscriber_benefit, subscription:).delivery_address).to be_nil
  end

  it "returns no report when there is no campaign" do
    general = create(:subscription, campaign: nil)
    benefit = create(:subscriber_benefit, subscription: general)

    expect(benefit.send(:latest_report)).to be_nil
  end
end
