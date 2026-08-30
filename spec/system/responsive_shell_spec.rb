# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Responsive application shell" do
  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  def visit_shell
    visit "/rails/view_components/app_shell_component/default"
  end

  it "fits the viewport at phone, tablet and desktop widths" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit_shell

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  it "opens with Enter, traps focus and closes with Escape" do
    page.current_window.resize_to(375, 900)
    visit_shell
    trigger = page.find("[data-app-shell-target='toggle']")

    trigger.send_keys(:enter)

    expect(trigger["aria-expanded"]).to eq("true")
    expect(page).to have_css("[data-app-shell-target='drawer'].translate-x-0")

    page.find("[data-app-shell-target='drawer'] a").send_keys(:escape)

    expect(trigger["aria-expanded"]).to eq("false")
    expect(page.evaluate_script("document.activeElement === document.querySelector('[data-app-shell-target=toggle]')"))
      .to be(true)
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
