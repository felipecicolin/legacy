# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Icon SVG catalog" do
  ICONS_DIR = Rails.root.join("app/assets/images/icons")
  REQUIRED_NAMES = %w[
    alert-octagon alert-triangle arrow-left blueprint building calendar camera
    chart-bar check-circle chevron-down chevron-right clock close download
    external-link filter globe hand-heart hard-hat home map-pin menu paperclip
    pause-circle pencil plus receipt search share trash upload users wallet
  ].freeze

  let(:svg_paths) { ICONS_DIR.glob("*.svg") }

  it "ships the complete foundation catalog" do
    names = svg_paths.map { |path| path.basename(".svg").to_s }

    expect(names).to include(*REQUIRED_NAMES)
  end

  it "keeps every SVG normalized for currentColor" do
    svg_paths.each do |path|
      svg = path.read

      aggregate_failures(path.basename.to_s) do
        expect(svg).to include('viewBox="0 0 24 24"')
        expect(svg).to include('stroke="currentColor"')
        expect(svg).to include('stroke-width="1.5"')
        expect(svg).to include('stroke-linecap="round"')
        expect(svg).to include('stroke-linejoin="round"')
        expect(svg).not_to match(/(?:\A|\s)(?:width|height|id|class|style)\s*=/)
        expect(svg).not_to match(/#[0-9a-f]{3,8}\b/i)
      end
    end
  end
end
