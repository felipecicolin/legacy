# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectParticipation do
  subject(:participation) { build(:project_participation) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:profile) }

  it "allows two roles for one person but not a duplicate role" do
    project = create(:project)
    profile = create(:profile)
    create(:project_participation, project:, profile:, role: :volunteer)

    expect(build(:project_participation, project:, profile:, role: :technical_lead)).to be_valid
    expect(build(:project_participation, project:, profile:, role: :volunteer)).not_to be_valid
  end

  it "does not grant an effective role to an invitation" do
    participation.status = :invited

    expect(participation.effective_role).to be_nil
    expect(participation).not_to be_can_submit_progress_report
  end

  it "allows a coordinator to submit progress" do
    participation.status = :active
    participation.role = :coordinator

    expect(participation.effective_role).to eq("coordinator")
    expect(participation).to be_can_submit_progress_report
  end

  it "requires an end date after the start date" do
    expect(build(:project_participation, started_on: Date.current, ended_on: 1.day.ago.to_date)).not_to be_valid
  end

  it "uses the project sensitivity for visibility" do
    expect(participation.visibility_subject).to eq(participation.project)
    expect(described_class.visible_to(Visibility::Context.anonymous)).to be_a(ActiveRecord::Relation)
  end
end
