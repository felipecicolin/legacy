# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardComponent, type: :component do
  def render_card_with(header: nil, footer: nil)
    render_inline(described_class.new) do |card|
      card.with_header { header } if header
      card.with_footer { footer } if footer
      "Conteúdo"
    end
  end

  describe "variants" do
    it "renders the default variant" do
      render_inline(described_class.new) { "Conteúdo" }

      expect(page).to have_css("div.bg-card.border.border-border.rounded-lg")
      expect(page).to have_no_css("div.shadow-sm")
    end

    it "renders the elevated variant" do
      render_inline(described_class.new(variant: "elevated")) { "Conteúdo" }

      expect(page).to have_css("div.bg-card.shadow-sm.rounded-lg")
      expect(page).to have_no_css("div.border-border")
    end

    it "renders the outlined variant" do
      render_inline(described_class.new(variant: "outlined")) { "Conteúdo" }

      expect(page).to have_css("div.bg-transparent.border.border-border.rounded-lg")
      expect(page).to have_no_css("div.bg-card")
    end
  end

  it "rejects an invalid variant during construction" do
    expect { described_class.new(variant: "floating") }
      .to raise_error(ArgumentError, /invalid variant/)
  end

  it "renders without a header or footer" do
    render_inline(described_class.new) { "Conteúdo" }

    expect(page).to have_no_css("header")
    expect(page).to have_no_css("footer")
  end

  it "renders a header without a footer" do
    render_card_with(header: "Cabeçalho")

    expect(page).to have_css("header", text: "Cabeçalho")
    expect(page).to have_no_css("footer")
  end

  it "renders a footer without a header" do
    render_card_with(footer: "Rodapé")

    expect(page).to have_no_css("header")
    expect(page).to have_css("footer", text: "Rodapé")
  end

  it "renders both slots" do
    render_card_with(header: "Cabeçalho", footer: "Rodapé")

    expect(page).to have_css("header", text: "Cabeçalho")
    expect(page).to have_css("footer", text: "Rodapé")
  end

  it "lets caller classes override the default padding" do
    render_inline(described_class.new(class: "p-6")) { "Conteúdo" }

    classes = page.find("div")[:class].split
    expect(classes).to include("p-6")
    expect(classes).not_to include("p-4")
  end
end
