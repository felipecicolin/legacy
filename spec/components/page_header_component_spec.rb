# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageHeaderComponent, type: :component do
  it "renders only the title when optional content is absent" do
    render_inline(described_class.new(title: "Obras"))

    expect(page).to have_css("header h1", text: "Obras")
    expect(page).to have_no_css("header p")
    expect(page).to have_no_css("header nav")
    expect(page).to have_no_css("header a")
  end

  it "renders a subtitle and caller classes" do
    render_inline(described_class.new(title: "Obras", subtitle: "Acompanhe o avanço.", class: "mb-0"))

    expect(page).to have_css("header.mb-0 p", text: "Acompanhe o avanço.")
  end

  it "renders one breadcrumb without a separator" do
    render_inline(described_class.new(title: "Detalhes")) do |header|
      header.with_breadcrumb(label: "Detalhes")
    end

    expect(page).to have_css("nav[aria-label='Caminho da página'] li", count: 1, text: "Detalhes")
    expect(page).to have_no_css("nav li[aria-hidden='true']")
  end

  it "renders linked breadcrumbs, separators and actions" do
    render_full_header

    expect(page).to have_link("Obras", href: "/obras")
    expect(page).to have_css("nav li[aria-hidden='true']", count: 2)
    expect(page).to have_css("header div", text: "Ações")
  end

  private

  def render_full_header
    render_inline(described_class.new(title: "Detalhes")) do |header|
      header.with_breadcrumb(label: "Obras", href: "/obras")
      header.with_breadcrumb(label: "Centro comunitário")
      header.with_breadcrumb(label: "Detalhes")
      header.with_actions { "Ações" }
    end
  end
end
