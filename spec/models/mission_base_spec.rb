# frozen_string_literal: true

require "rails_helper"

RSpec.describe MissionBase do
  subject(:base) { build(:mission_base) }

  it { is_expected.to belong_to(:country) }
  it { is_expected.to belong_to(:region).optional }
  it { is_expected.to belong_to(:organization).optional }
  it { is_expected.to have_many(:projects).dependent(:restrict_with_error) }
  it { is_expected.to have_rich_text(:description) }
  it { is_expected.to have_one_attached(:cover_image) }

  it "scrubs metadata from the cover image" do
    base.save!
    base.cover_image.attach(GeotaggedPhoto.upload(filename: "capa.jpg"))

    expect(base.reload.cover_image).to be_attached
    expect(base.cover_image.blob.download).not_to include(GeotaggedPhoto::MARKER)
  end

  it "starts restricted and labels enums in Portuguese" do
    expect(base.sensitivity_level).to eq("restricted")
    expect(base.kind_label).to eq("Base missionária")
    expect(base.status_label).to eq("Pendente")
  end

  it "generates a unique slug and keeps it immutable" do
    base.save!
    slug = base.slug

    expect { base.update!(name: "Outro nome", slug: "outro") }
      .to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(base.reload.slug).to eq(slug)
  end

  it "adds a suffix when the name already has a slug" do
    create(:mission_base, name: "Base Repetida", slug: "base-repetida")
    second = build(:mission_base, name: "Base Repetida", slug: nil)
    second.save!

    expect(second.slug).to start_with("base-repetida-")
  end

  it "keeps the base slug when no collision exists" do
    value = build(:mission_base, name: "Base Exclusiva", slug: nil)
    value.save!

    expect(value.slug).to eq("base-exclusiva")
  end

  it "returns nil labels when location associations are absent" do
    value = described_class.new

    expect(value.country_label).to be_nil
    expect(value.region_label).to be_nil
  end

  it "does not list pending bases" do
    pending_base = create(:mission_base)

    expect(described_class.visible).not_to include(pending_base)
  end

  it "exposes an active public base to anonymous context" do
    active_base = create(:mission_base, status: :active)
    active_base.promote_visibility!(level: :public, author: create(:user), justification: "Vitrine")

    expect(described_class.visible_to(Visibility::Context.anonymous)).to include(active_base)
    expect(described_class.hidden_from(Visibility::Context.anonymous)).not_to include(active_base)
  end

  it "inherits a high-risk country's confidential policy and refuses coordinates" do
    country = create(:country, high_risk: true)

    expect(build(:mission_base, country:, latitude: 1, longitude: 2)).not_to be_valid
    expect(build(:mission_base, country:).sensitivity_level).to eq("restricted")
    expect(create(:mission_base, country:).sensitivity_level).to eq("confidential")
  end

  it "refuses an explicitly public base at creation" do
    expect(build(:mission_base, sensitivity_level: :public)).not_to be_valid
  end

  it "keeps the region in the same country" do
    other_country = create(:country)
    region = create(:region, country: other_country)

    expect(build(:mission_base, region:)).not_to be_valid
  end

  it "accepts a base without a project" do
    expect { base.save! }.not_to raise_error
    expect(base.projects).to be_empty
  end

  it "refuses to destroy a base with projects" do
    create(:project, mission_base: base)
    base.save!

    expect { base.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end
end
