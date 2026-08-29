# frozen_string_literal: true

require "rails_helper"

RSpec.describe Visibility::Context do
  it "gives an anonymous reader only the public level" do
    expect(described_class.anonymous.allowed_levels).to eq([:public])
  end

  it "gives a reader every level up to their clearance" do
    expect(described_class.new(clearance: :restricted).allowed_levels)
      .to eq(%i[public restricted])
  end

  it "hides the precise location of a record above the clearance" do
    record = SensitiveTestRecord.new(sensitivity_level: :restricted)

    expect(described_class.anonymous).not_to be_can_see_precise_location(record)
  end

  it "shows the precise location of a record within the clearance" do
    record = SensitiveTestRecord.new(sensitivity_level: :restricted)

    expect(described_class.new(clearance: :confidential))
      .to be_can_see_precise_location(record)
  end
end
