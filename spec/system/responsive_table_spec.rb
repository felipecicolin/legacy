# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Responsive table" do
  it "keeps horizontal overflow inside its table container" do
    page.current_window.resize_to(375, 900)
    visit "/rails/view_components/table_component/default"

    expect(page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")).to be(true)
    expect(page).to have_css("[class*='overflow-x-auto']")
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
