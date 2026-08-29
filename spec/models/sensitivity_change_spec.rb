# frozen_string_literal: true

require "rails_helper"

RSpec.describe SensitivityChange do
  subject(:change) do
    described_class.new(record: SensitiveTestRecord.new, author: build(:user),
                        from_level: :restricted, to_level: :public,
                        justification: "Consentimento da equipe local")
  end

  it { is_expected.to belong_to(:record) }
  it { is_expected.to validate_presence_of(:justification) }

  it "keeps the two level enums apart" do
    expect(change).to be_from_level_restricted.and be_to_level_public
  end

  it "refuses a level outside the enum" do
    change.to_level = "vitrine"

    expect(change).not_to be_valid
  end
end
