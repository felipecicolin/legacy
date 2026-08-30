# frozen_string_literal: true

require "rails_helper"

RSpec.describe MissionBasePolicy do
  let(:anonymous) { Authorization::Context.anonymous }

  def public_record(code)
    record = SensitiveTestRecord.create!(code:)
    record.promote_visibility!(level: :public, author: create(:user), justification: "Catálogo público")
    record
  end

  it "allows public listing and only visible records" do
    policy = described_class.new(anonymous, public_record("PB-01"))
    hidden_policy = described_class.new(anonymous, SensitiveTestRecord.create!(code: "PB-02"))

    expect(policy).to be_index
    expect(policy).to be_show
    expect(hidden_policy).not_to be_show
  end

  it "uses the visibility scope" do
    visible = SensitiveTestRecord.create!(code: "PB-01")
    visible.promote_visibility!(level: :public, author: create(:user), justification: "Catálogo público")
    SensitiveTestRecord.create!(code: "PB-02")

    expect(described_class::Scope.new(anonymous, SensitiveTestRecord.all).resolve).to contain_exactly(visible)
  end
end
