# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectDetailComponent, type: :component do
  it "renders the three grouped tabs with the project presenter" do
    render_detail
    expect_tab_structure
  end

  private

  def render_detail
    project = create(:project, title: "Obra renderizada")
    presenter = ProjectDetailPresenter.new(project, Authorization::Context.anonymous)
    render_inline(described_class.new(presenter:))
  end

  def expect_tab_structure
    expect(page).to have_css("h1", text: "Obra renderizada")
    expect(page).to have_css("[role='tablist'] [role='tab']", count: 3)
    expect_panels
  end

  def expect_panels
    expect(page).to have_css("[role='tabpanel']", count: 3, visible: :all)
    expect(page).to have_css("turbo-frame#project-reports", visible: :all)
  end
end
