# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement do
  subject(:disbursement) { build(:disbursement) }

  it { is_expected.to belong_to(:ngo) }
  it { is_expected.to belong_to(:campaign).optional }
  it { is_expected.to define_enum_for(:status).with_values(Disbursement::STATUSES) }

  it "labels each status in Portuguese" do
    expect(build(:disbursement, status: :scheduled).status_label).to eq("Agendado")
    expect(build(:disbursement, status: :executed, executed_on: Date.current).status_label).to eq("Executado")
    expect(build(:disbursement, status: :cancelled).status_label).to eq("Cancelado")
  end

  it "inherits the NGO sensitivity on creation" do
    ngo = create(:ngo, :active, sensitivity_level: :confidential)
    record = build(:disbursement, ngo:, sensitivity_level: :restricted)

    expect(record).to be_valid
    expect(record.sensitivity_level).to eq("confidential")
  end

  it "rejects a sensitivity level less restrictive than the NGO" do
    ngo = create(:ngo, :active)
    record = build(:disbursement, ngo:, sensitivity_level: :public)
    allow(record).to receive(:inherit_ngo_sensitivity)

    expect(record).not_to be_valid
    expect(record.errors[:sensitivity_level]).to include("A obra não pode ser menos restrita que a ONG a que pertence.")
  end

  it "rejects a campaign belonging to another NGO" do
    record = build(:disbursement, ngo: create(:ngo, :active), campaign: create(:campaign))

    expect(record).not_to be_valid
    expect(record.errors[:campaign]).to include("A obra precisa pertencer à ONG da campanha.")
  end

  it "rejects a campaign with a different currency" do
    campaign = build(:campaign, currency: "USD")
    record = build(:disbursement, ngo: campaign.ngo, campaign:, currency: "BRL")

    expect(record).not_to be_valid
    expect(record.errors[:currency]).to include("A moeda precisa ser a mesma do recurso relacionado.")
  end

  it "requires an execution date for executed repasses" do
    expect(build(:disbursement, status: :executed)).not_to be_valid
    expect(build(:disbursement, :executed)).to be_valid
  end

  it "keeps execution after the scheduled date" do
    record = build(:disbursement, status: :executed, scheduled_on: Date.current,
                                  executed_on: Date.current - 1.day)

    expect(record).not_to be_valid
    expect(record.errors[:executed_on]).to include("Deve ser posterior ou igual à data agendada.")
  end

  it "keeps simulated status immutable" do
    record = create(:disbursement)

    expect { record.update!(simulated: false) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end
end
