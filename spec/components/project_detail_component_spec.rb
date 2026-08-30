# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectDetailComponent, type: :component do
  it "renders the six anchored sections with the project presenter" do
    render_detail
    expect_anchored_sections
  end

  private

  def render_detail
    project = create(:project, title: "Obra renderizada")
    presenter = ProjectDetailPresenter.new(project, Authorization::Context.anonymous)
    render_inline(described_class.new(presenter:))
  end

  def expect_anchored_sections
    aggregate_failures do
      expect(page).to have_css("h1", text: "Obra renderizada")
      %w[progress phases team needs funding].each { |section| expect(page).to have_css("##{section}") }
      expect(page).to have_css("#reports turbo-frame#project-reports")
    end
  end
end
