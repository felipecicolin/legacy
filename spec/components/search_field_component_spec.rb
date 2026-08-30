# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchFieldComponent, type: :component do
  it "renders a labelled search input and a Turbo GET form" do
    render_search

    expect(page).to have_css("form[action='/obras'][method='get'][data-turbo-frame='results']")
    expect(page).to have_css("label[for='query']", text: "Buscar")
    expect(page).to have_link("Limpar busca", href: "/obras")
  end

  it "keeps Turbo enabled without a frame and merges root classes" do
    render_inline(described_class.new(url: "/busca", class: "max-w-xl"))

    expect(page).to have_css("div.max-w-xl form:not([data-turbo-frame])")
    expect(page).to have_field(type: "search")
    expect(page).to have_no_css("[data-turbo='false']")
    expect(page).to have_link("Limpar busca", href: "/busca")
  end

  private

  def render_search
    render_inline(described_class.new(url: "/obras", frame: "results", value: "centro"))
  end
end
