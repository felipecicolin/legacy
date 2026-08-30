# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffRole do
  it "refuses a level outside the enum as a validation, not an exception" do
    role = build(:staff_role).tap { |record| record.staff_level = "superuser" }

    aggregate_failures do
      expect(role).not_to be_valid
      expect(role.errors[:staff_level]).to be_present
    end
  end

  it "keeps one role per person" do
    user = create(:user)
    create(:staff_role, user: user)

    expect(build(:staff_role, user: user)).not_to be_valid
  end

  it "labels the level in pt-BR" do
    expect(build(:staff_role, :admin).staff_level_label).to eq("Administração da plataforma")
  end

  it "orders the levels by reach" do
    expect(described_class.staff_levels).to eq("support" => 0, "curator" => 1, "admin" => 2)
  end
end
