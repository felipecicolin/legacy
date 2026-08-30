# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectPolicy do
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user:) }
  let(:context) { Authorization::Context.for(user) }
  let(:project) { create(:organization, organization_status: :approved) }

  def public_record(code)
    record = SensitiveTestRecord.create!(code:)
    record.promote_visibility!(level: :public, author: create(:user), justification: "Catálogo público")
    record
  end

  it "allows the public project list and visible records" do
    anonymous = Authorization::Context.anonymous
    policy = described_class.new(anonymous, public_record("PB-01"))

    expect(policy).to be_index
    expect(policy).to be_show
  end

  it "requires a project participant to report progress" do
    participation = Struct.new(:role).new("representative")
    participations = instance_double(ActiveRecord::Relation)
    allow(participations).to receive(:find_by).with(profile:).and_return(participation)
    project_record = Struct.new(:project_participations).new(participations)

    expect(described_class.new(context, project_record)).to be_progress_report
  end

  it "does not let an unrelated person report progress" do
    participations = instance_double(ActiveRecord::Relation)
    allow(participations).to receive(:find_by).with(profile:).and_return(nil)
    project_record = Struct.new(:project_participations).new(participations)

    expect(described_class.new(context, project_record)).not_to be_progress_report
  end

  it "lets a platform admin report progress without participation" do
    create(:staff_role, user:, staff_level: :admin)

    expect(described_class.new(Authorization::Context.for(user), project)).to be_progress_report
  end

  it "uses the visibility scope" do
    visible = SensitiveTestRecord.create!(code: "PB-01")
    visible.promote_visibility!(level: :public, author: create(:user), justification: "Catálogo público")
    SensitiveTestRecord.create!(code: "PB-02")

    expect(described_class::Scope.new(Authorization::Context.anonymous, SensitiveTestRecord.all).resolve)
      .to contain_exactly(visible)
  end
end
