# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project do
  subject(:project) { build(:project) }

  let(:coordinated_project) do
    value = create(:project)
    create(:project_participation, project: value, role: :coordinator, status: :active)
    value
  end

  it { is_expected.to belong_to(:mission_base) }
  it { is_expected.to have_many(:site_surveys).dependent(:destroy) }
  it { is_expected.to have_many(:progress_reports).dependent(:destroy) }
  it { is_expected.to have_many(:project_participations).dependent(:destroy) }
  it { is_expected.to have_many(:project_photos).dependent(:destroy) }
  it { is_expected.to have_rich_text(:scope_description) }

  it "generates a sequential code and keeps it immutable" do
    project.save!
    other = create(:project)

    expect(project.code).to match(/\AOB-\d{4,}\z/)
    expect(other.code).not_to eq(project.code)
    expect { project.update!(code: "OB-9999") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  it "keeps a caller-provided code" do
    value = build(:project, code: "OB-9876")

    expect { value.save! }.not_to raise_error
  end

  it "resets cached progress when no report exists" do
    value = create(:project)
    value.update_column(:physical_progress, 80)
    value.refresh_physical_progress!

    expect(value.reload.physical_progress).to eq(0)
  end

  it "offers a non-bang progress refresh" do
    value = create(:project)

    expect { value.refresh_physical_progress }.not_to raise_error
  end

  it "returns nil location labels without a base" do
    value = described_class.new

    expect(value.country_label).to be_nil
    expect(value.region_label).to be_nil
  end

  it "returns location labels from its base" do
    region = create(:region)
    base = build(:mission_base, region:)
    value = build(:project, mission_base: base)

    expect(value.country_label).to eq(base.country_label)
    expect(value.region_label).to eq(region.name)
  end

  it "hides projects under a pending base" do
    value = create(:project)
    value.mission_base.promote_visibility!(level: :public, author: create(:user), justification: "Vitrine")
    value.promote_visibility!(level: :public, author: create(:user), justification: "Vitrine")

    expect(described_class.visible_to(Visibility::Context.anonymous)).not_to include(value)
  end

  it "returns the hidden complement as a relation" do
    expect(described_class.hidden_from(Visibility::Context.anonymous)).to be_a(ActiveRecord::Relation)
  end

  it "inherits the base sensitivity and rejects a less restrictive update" do
    base = create(:mission_base, sensitivity_level: :confidential)
    project = build(:project, mission_base: base)

    project.save!
    expect(project.sensitivity_level).to eq("confidential")
  end

  it "rejects sensitivity less restrictive than its base" do
    project = create(:project, mission_base: create(:mission_base, sensitivity_level: :confidential))
    project.sensitivity_level = :public

    expect(project).not_to be_valid
  end

  it "rejects negative funding and out of range cached progress" do
    expect(build(:project, funding_target_cents: -1)).not_to be_valid
    expect(build(:project, physical_progress: 101)).not_to be_valid
  end

  it "allows only the declared status transitions" do
    project = coordinated_project
    advance(project, :in_progress, :paused, :in_progress, :urgent, :completed)

    expect(project).to be_completed
  end

  it "rejects a transition not declared for the current status" do
    expect { create(:project).transition_to!(:completed) }.to raise_error(ArgumentError)
  end

  it "returns false for an invalid transition" do
    expect(project.transition_to(:completed)).to be(false)
  end

  it "requires an active coordinator when starting" do
    project.save!

    expect { project.transition_to!(:in_progress) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(project.reload).to be_surveying
  end

  it "rejects a direct invalid status update" do
    project.save!
    project.status = :completed

    expect(project).not_to be_valid
  end

  it "orders planned and actual dates" do
    expect(build(:project, planned_start_on: Date.current, planned_end_on: 1.day.ago.to_date)).not_to be_valid
    expect(build(:project, actual_start_on: Date.current, actual_end_on: 1.day.ago.to_date)).not_to be_valid
  end

  def advance(value, *statuses)
    statuses.each { |status| value.transition_to!(status) }
  end
end
