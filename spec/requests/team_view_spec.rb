# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team view" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password: password) }
  let(:profile) { create(:profile, user: user) }
  let(:ngo) { create(:ngo, :active) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: password }
  end

  it "offers a way in to someone who signed in without a profile" do
    sign_in

    get team_path

    expect(response.body).to include(I18n.t("teams.no_profile.empty_title"))
  end

  it "says so instead of showing an empty board to someone on no team" do
    profile
    sign_in

    get team_path

    expect(response.body).to include(I18n.t("teams.show.empty_title"))
  end

  it "shows the schedule and the money of a project the person works on" do
    project = create(:project, ngo: ngo, planned_end_on: 3.months.from_now.to_date)
    create(:project_participation, :coordinator, project: project, profile: profile)
    sign_in

    get team_path

    aggregate_failures do
      expect(response.body).to include(project.title)
      expect(response.body).to include(I18n.t("teams.show.delivery"))
    end
  end
end
