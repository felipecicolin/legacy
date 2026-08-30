# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Fundraising dashboard screen" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password:) }

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
    create(:staff_role, :admin, user:)
    create_list(:disbursement, 2)
    sign_in
  end

  it "keeps tables and the body inside the viewport at every breakpoint" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit admin_fundraising_path

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
    expect(page).to have_css("[class*='overflow-x-auto']")
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
