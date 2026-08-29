# frozen_string_literal: true

require "rails_helper"

RSpec.describe ButtonComponent, type: :component do
  describe "validation" do
    it "refuses an unknown variant" do
      expect { described_class.new(variant: :fancy) }.to raise_error(ArgumentError, /invalid variant/)
    end

    it "refuses a size outside the scale" do
      expect { described_class.new(size: :huge) }.to raise_error(ArgumentError, /invalid size/)
    end

    it "refuses a type the button element does not accept" do
      expect { described_class.new(type: :menu) }.to raise_error(ArgumentError, /invalid type/)
    end
  end

  describe "#computed_classes" do
    it "combines the base, variant and size classes" do
      expect(described_class.new(variant: :destructive, size: :lg).computed_classes)
        .to include("inline-flex", "bg-destructive", "h-12")
    end

    it "lets the caller's classes win over the size defaults" do
      classes = described_class.new(size: :md, classes: "h-16").computed_classes

      expect(classes).to include("h-16")
      expect(classes).not_to include("h-11")
    end
  end

  describe "#link?" do
    it "is a link when an href is given" do
      expect(described_class.new(href: "/painel")).to be_link
    end

    it "is a button otherwise" do
      expect(described_class.new).not_to be_link
    end
  end

  describe "rendering" do
    it "renders a <button> carrying the type and the label" do
      render_inline(described_class.new(label: "Salvar", type: :submit))

      expect(page).to have_button("Salvar", type: "submit")
    end

    it "renders an <a> when an href is given" do
      render_inline(described_class.new(label: "Voltar", href: "/painel"))

      expect(page).to have_link("Voltar", href: "/painel")
    end

    it "marks a disabled button as disabled" do
      render_inline(described_class.new(label: "Aguardando", disabled: true))

      expect(page).to have_css("button[disabled]")
    end

    it "passes data attributes through to the element" do
      render_inline(described_class.new(label: "Abrir", data: { turbo_frame: "modal" }))

      expect(page).to have_css("button[data-turbo-frame='modal']")
    end

    it "falls back to the block content when no label is given" do
      render_inline(described_class.new) { "Conteúdo em bloco" }

      expect(page).to have_button("Conteúdo em bloco")
    end
  end

  describe "icon slots" do
    it "renders the leading icon inside the button" do
      render_inline(described_class.new(label: "Adicionar")) { |button| button.with_leading_icon(name: "plus") }

      expect(page).to have_css("button svg")
    end

    it "renders the trailing icon inside the button" do
      render_inline(described_class.new(label: "Avançar")) { |button| button.with_trailing_icon(name: "arrow-right") }

      expect(page).to have_css("button svg")
    end
  end
end
