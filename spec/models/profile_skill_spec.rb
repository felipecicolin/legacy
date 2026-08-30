# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfileSkill do
  subject(:profile_skill) { build(:profile_skill) }

  it { is_expected.to belong_to(:profile) }
  it { is_expected.to belong_to(:skill) }
  it { is_expected.to define_enum_for(:proficiency).with_values(beginner: 0, intermediate: 1, advanced: 2, expert: 3) }
  it { is_expected.to validate_presence_of(:proficiency) }

  it "refuses a second profile skill for the same pair" do
    existing = create(:profile_skill)

    expect(build(:profile_skill, profile: existing.profile, skill: existing.skill)).not_to be_valid
  end

  it "lets the database refuse a duplicate pair" do
    existing = create(:profile_skill)
    duplicate = build(:profile_skill, profile: existing.profile, skill: existing.skill)

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "refuses a proficiency outside the enum" do
    profile_skill.proficiency = "master"

    expect(profile_skill).not_to be_valid
  end

  it "refuses a negative experience" do
    expect(build(:profile_skill, years_of_experience: -1)).not_to be_valid
  end

  it "accepts an unknown experience" do
    expect(build(:profile_skill, years_of_experience: nil)).to be_valid
  end

  it "shows the proficiency through the pt-BR vocabulary" do
    expect(build(:profile_skill, proficiency: :advanced).proficiency_label).to eq("Avançado")
  end

  it "is removed with its profile" do
    profile_skill = create(:profile_skill)

    expect { profile_skill.profile.destroy! }.to change(described_class, :count).by(-1)
  end
end
