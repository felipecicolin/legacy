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

  # Reescrever a linha não deixa lacuna: deixa uma resposta errada com cara de
  # legítima para "quem abriu esta obra".
  it "refuses to be rewritten once persisted" do
    record = SensitiveTestRecord.create!(code: "IM-01")
    record.promote_visibility!(level: :public, author: create(:user),
                               justification: "Consentimento da equipe local")

    expect { record.sensitivity_changes.sole.update!(justification: "Outro") }
      .to raise_error(SensitivityChange::Immutable)
  end
end
