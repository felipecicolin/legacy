# frozen_string_literal: true

require "rails_helper"

RSpec.describe IconComponent, type: :component do
  describe ".available_names" do
    it "lists the svg catalog by basename, sorted" do
      expect(described_class.available_names).to include("check", "plus").and eq(described_class.available_names.sort)
    end
  end

  describe "validation" do
    it "refuses a size outside the scale" do
      expect { described_class.new(name: "check", size: :huge) }.to raise_error(ArgumentError, /invalid size/)
    end

    it "refuses a name the catalog does not ship, instead of rendering nothing" do
      expect { described_class.new(name: "definitely-not-an-icon") }
        .to raise_error(ArgumentError, /not found in/)
    end
  end

  describe "#render_options" do
    it "hides a bare icon from screen readers" do
      options = described_class.new(name: "check").render_options

      expect(options).to include(aria_hidden: "true")
      expect(options).not_to include(:title)
    end

    it "exposes a labelled icon as content" do
      expect(described_class.new(name: "check", label: "Pronto").render_options)
        .to include(title: "Pronto", aria: true)
    end

    it "merges the size class with the caller's extra classes" do
      expect(described_class.new(name: "check", size: :lg, classes: "text-primary").render_options[:class])
        .to include("w-6", "h-6", "text-primary")
    end
  end

  describe "rendering" do
    it "inlines the svg from the catalog" do
      render_inline(described_class.new(name: "check"))

      expect(page).to have_css("svg.w-5[aria-hidden='true']")
    end

    it "inherits the color from its context" do
      render_inline(described_class.new(name: "search"))

      expect(page).to have_css("svg[stroke='currentColor']")
    end
  end
end
