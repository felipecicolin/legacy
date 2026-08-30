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

  # Duas perguntas, dois nomes, uma regra hoje. Os exemplos são separados
  # porque o dia em que identificar gente pedir mais que ver a obra, é aqui
  # que a diferença aparece.
  it "refuses to identify a person beside a record above the clearance" do
    record = SensitiveTestRecord.new(sensitivity_level: :confidential)

    expect(described_class.new(clearance: :restricted)).not_to be_can_identify(record)
  end

  it "identifies a person beside a record within the clearance" do
    record = SensitiveTestRecord.new(sensitivity_level: :restricted)

    expect(described_class.new(clearance: :restricted)).to be_can_identify(record)
  end
end
