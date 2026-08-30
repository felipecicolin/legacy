# frozen_string_literal: true

require "rails_helper"

RSpec.describe SiteSurvey do
  subject(:survey) { build(:site_survey) }

  let(:public_project) do
    project = create(:project)
    project.mission_base.update!(status: :active)
    project.mission_base.promote_visibility!(level: :public, author: create(:user), justification: "Vitrine")
    project.promote_visibility!(level: :public, author: create(:user), justification: "Vitrine")
    project
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:surveyed_by).class_name("Profile") }
  it { is_expected.to have_rich_text(:findings) }
  it { is_expected.to have_rich_text(:recommendations) }
  it { is_expected.to have_many_attached(:documents) }

  it "allows an empty draft" do
    expect(survey).to be_valid
  end

  it "requires findings to submit" do
    survey.status = :submitted

    expect(survey).not_to be_valid
  end

  it "rejects an empty rich text finding" do
    survey.status = :submitted
    survey.findings = "<div><br></div>"

    expect(survey).not_to be_valid
  end

  it "submits a survey with findings" do
    survey.findings = "<div>Diagnóstico concluído</div>"

    expect { survey.submit! }.not_to raise_error
  end

  it "returns false when a survey cannot be submitted" do
    expect(survey.submit).to be(false)
  end

  it "only exposes submitted surveys from visible projects" do
    survey = build(:site_survey, project: public_project)
    survey.findings = "<div>Diagnóstico concluído</div>"
    survey.submit!

    expect(described_class.visible_to(Visibility::Context.anonymous)).to include(survey)
  end

  it "rejects future dates and negative costs" do
    expect(build(:site_survey, surveyed_on: 1.day.from_now.to_date)).not_to be_valid
    expect(build(:site_survey, estimated_cost_cents: -1)).not_to be_valid
  end

  it "points attachment visibility at the project" do
    expect(survey.visibility_subject).to eq(survey.project)
  end
end
