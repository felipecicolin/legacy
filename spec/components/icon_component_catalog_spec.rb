# frozen_string_literal: true

require "rails_helper"

ICON_CATALOG_DIR = Rails.root.join("app/assets/images/icons")
REQUIRED_ICON_NAMES = %w[
  alert-octagon alert-triangle arrow-left blueprint building calendar camera
  chart-bar check-circle chevron-down chevron-right clock close download
  external-link filter globe hand-heart hard-hat home map-pin menu paperclip
  pause-circle pencil plus receipt search share trash upload users wallet
].freeze
NORMALIZED_ICON_MARKERS = [
  'viewBox="0 0 24 24"',
  'stroke="currentColor"',
  'stroke-width="1.5"',
  'stroke-linecap="round"',
  'stroke-linejoin="round"',
].freeze
FORBIDDEN_ICON_ATTRIBUTES = /(?:\A|\s)(?:width|height|id|class|style)\s*=/
ICON_HEX_COLOR = /#[0-9a-f]{3,8}\b/i

RSpec.describe IconComponent, type: :component do
  let(:svg_paths) { ICON_CATALOG_DIR.glob("*.svg") }

  it "ships the complete foundation catalog" do
    names = svg_paths.map { |path| path.basename(".svg").to_s }

    expect(names).to include(*REQUIRED_ICON_NAMES)
  end

  it "keeps every SVG normalized for currentColor" do
    svg_paths.each do |path|
      svg = path.read

      aggregate_failures(path.basename.to_s) do
        expect(svg).to include(*NORMALIZED_ICON_MARKERS)
        expect(svg).not_to match(FORBIDDEN_ICON_ATTRIBUTES)
        expect(svg).not_to match(ICON_HEX_COLOR)
      end
    end
  end
end
