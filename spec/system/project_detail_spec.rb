# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Project detail" do
  let(:project) do
    obra = create(:project, ngo: create(:ngo, :active, :listed), title: "Obra pública de teste")
    obra.promote_visibility!(level: :public, author: create(:user), justification: "Publicação")
    obra
  end

  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  it "fits the body at the required responsive breakpoints" do
    visit project_path(project.code)

    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  it "exposes the grouped tabs and the Turbo report frame" do
    page.current_window.resize_to(1440, 900)
    visit project_path(project.code)

    expect(page).to have_css("[role='tablist'] [role='tab']", count: 3)
    expect(page).to have_css("turbo-frame#project-reports")
  end
end
