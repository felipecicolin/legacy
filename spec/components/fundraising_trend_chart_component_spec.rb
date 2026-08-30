# frozen_string_literal: true

require "rails_helper"

RSpec.describe FundraisingTrendChartComponent, type: :component do
  let(:point) do
    FundraisingTrend::Point.new(month: Date.current, label: "08/2026",
                                amounts: { one_off: 1_000, recurring: 2_000, in_kind: 3_000, event_store: 4_000 })
  end

  it "renders a server-side chart and an accessible legend" do
    render_chart

    expect(page).to have_css("svg[role='img'][viewbox='0 0 720 280']")
  end

  it "renders four semantic channel bars and an accessible legend" do
    render_chart

    expect_bar_colors
    expect(page.text).to include("Doações pontuais", "Doações em espécie")
  end

  it "keeps an empty chart accessible without dividing by zero" do
    render_inline(described_class.new(points: []))

    expect(page).to have_css("svg[role='img'] line.stroke-border")
  end

  private

  def render_chart
    render_inline(described_class.new(points: [point]))
  end

  def expect_bar_colors
    expect(page.native.to_s).to include("fill-primary", "fill-accent", "fill-category-3", "fill-category-4")
  end
end
