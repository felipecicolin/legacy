# frozen_string_literal: true

require "rails_helper"

RSpec.describe Receipt do
  let(:first) { create(:contribution, :confirmed, provider_reference: "SIM-receipt-a").receipt }
  let(:second) { create(:contribution, :confirmed, provider_reference: "SIM-receipt-b").receipt }

  it "numbers receipts by year" do
    expect(first.number).to match(/\A#{first.issued_year}-\d{6}\z/)
  end

  it "keeps receipt numbers unique" do
    expect(second.number).not_to eq(first.number)
  end

  it "copies immutable payment details" do
    expect(first.amount_cents).to eq(first.contribution.amount_cents)
  end

  it "copies the payment currency" do
    expect(first.currency).to eq("BRL")
  end

  it "marks the PDF as simulated" do
    expect(first.simulated_mark).to eq("DADO SIMULADO — sem valor financeiro real")
  end

  it "does not add the simulated mark to a real receipt" do
    contribution = build(:contribution, :confirmed, simulated: false, provider_reference: "REAL-receipt")
    receipt = build(:receipt, contribution:)
    receipt.valid?

    expect(receipt.simulated_mark).to be_nil
  end

  it "exposes its donor" do
    expect(first.donor).to eq(first.contribution.contributor)
  end

  it "rejects a receipt for an unconfirmed contribution" do
    expect(build(:receipt, contribution: build(:contribution))).not_to be_valid
  end

  it "preserves a supplied number while deriving its year" do
    contribution = build(:contribution, :confirmed, provider_reference: "SIM-receipt-custom")
    receipt = build(:receipt, contribution:, number: "manual-1")

    expect(receipt).to be_valid
    expect(receipt.issued_year).to eq(receipt.issued_at.year)
  end

  it "preserves a supplied year and does not generate a number twice" do
    contribution = build(:contribution, :confirmed, provider_reference: "SIM-receipt-year")
    receipt = build(:receipt, contribution:, issued_year: 2020)

    expect(receipt).to be_valid
    expect(receipt.issued_year).to eq(2020)
    expect { receipt.send(:assign_number) }.not_to change(receipt, :number)
  end

  it "handles a missing contribution and an already attached PDF" do
    expect(build(:receipt, contribution: nil)).not_to be_valid
    expect { first.send(:attach_generated_pdf) }.not_to raise_error
  end
end
