# frozen_string_literal: true

require "rails_helper"

RSpec.describe Skill do
  subject(:skill) { build(:skill) }

  it { is_expected.to have_many(:profile_skills).dependent(:destroy) }
  it { is_expected.to have_many(:profiles).through(:profile_skills) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:category) }

  it "refuses a repeated key" do
    existing = create(:skill)

    expect(build(:skill, key: existing.key)).not_to be_valid
  end

  it "refuses a category outside the curated taxonomy" do
    expect(build(:skill, category: "medical")).not_to be_valid
  end

  it "refuses a negative position" do
    expect(build(:skill, position: -1)).not_to be_valid
  end

  it "requires an explicit active flag" do
    expect(build(:skill, active: nil)).not_to be_valid
  end

  it "resolves its name through the pt-BR vocabulary" do
    skill = build(:skill, key: "civil_engineering")

    expect(skill.name).to eq("Engenharia civil")
  end

  it "resolves its category through the pt-BR vocabulary" do
    expect(build(:skill, category: "engineering").category_label).to eq("Engenharia")
  end

  describe ".load_vocabulary!" do
    it "loads every curated skill" do
      described_class.load_vocabulary!

      expect(described_class.pluck(:key)).to match_array(Vocabulary::Catalog.skills.entries.pluck(:key))
    end

    it "has a translation for every stored key" do
      described_class.load_vocabulary!

      missing = described_class.pluck(:key).reject { |key| I18n.exists?("skills.#{key}") }

      expect(missing).to be_empty
    end

    it "does not duplicate a previous load" do
      described_class.load_vocabulary!

      expect { described_class.load_vocabulary! }.not_to change(described_class, :count)
    end

    it "updates an existing skill from the catalog" do
      skill = create(:skill, key: "civil_engineering", category: "trade", position: 99)

      described_class.load_vocabulary!

      expect(skill.reload).to have_attributes(category: "engineering", position: 10)
    end
  end

  it "is removed with its profile skills" do
    profile_skill = create(:profile_skill)

    expect { profile_skill.skill.destroy! }.to change(described_class, :count).by(-1)
  end
end
