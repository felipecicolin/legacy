# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer view screen" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password: password) }
  let(:profile) { create(:profile, user: user) }
  let(:mission_base) { create(:mission_base, :active) }

  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_on I18n.t("sessions.new.submit")
  end

  before do
    create(:profile_skill, profile: profile, skill: create(:skill))
    create_list(:need, 4, mission_base: mission_base)
    sign_in
  end

  it "fits the viewport at phone, tablet and desktop widths" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit needs_path

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
