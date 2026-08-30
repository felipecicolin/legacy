# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriberBenefitMailer do
  let(:benefit) { create(:subscriber_benefit) }
  let(:mail) { described_class.monthly_report(benefit) }

  before { benefit.prepare! }

  it "addresses the subscriber" do
    expect(mail.to).to eq([benefit.delivery_address])
  end

  it "uses the translated subject" do
    expect(mail.subject).to eq("Relatório mensal da sua assinatura")
  end

  it "includes report content" do
    expect(mail.body.encoded).to include(benefit.content)
  end
end
