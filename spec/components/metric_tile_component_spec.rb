# frozen_string_literal: true

require "rails_helper"

RSpec.describe MetricTileComponent, type: :component do
  it "renders the label, value and icon" do
    render_inline(described_class.new(label: "Obras ativas", value: "42", icon: "hard-hat"))

    expect(page).to have_text("Obras ativas")
    expect(page).to have_text("42")
    expect(page).to have_css("svg")
  end

  it "renders without an icon when none is given" do
    render_inline(described_class.new(label: "Voluntários ativos", value: "12"))

    expect(page).to have_no_css("svg")
  end

  it "shows a placeholder and a note instead of a value when pending" do
    render_inline(described_class.new(label: "Arrecadado no mês", pending: true))

    expect(page).to have_text("—")
    expect(page).to have_text("Aguarda arrecadação")
  end
end
