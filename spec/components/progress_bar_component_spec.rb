# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressBarComponent, type: :component do
  it "clamps physical progress and keeps the raw percentage in aria" do
    [0, 1, 62, 100, 140, -5].each { |value| expect_physical_progress(value) }
  end

  it "calculates funding progress, clamps overfunding and handles missing targets" do
    examples = [[184_000, 300_000, 61.3333333333, "R$ 184.000,00 de R$ 300.000,00"],
                [300_000, 300_000, 100.0, "R$ 300.000,00 de R$ 300.000,00"],
                [400_000, 300_000, 100.0, "R$ 400.000,00 de R$ 300.000,00"],
                [184_000, 0, 0.0, "R$ 184.000,00 de R$ 0,00"],
                [184_000, nil, 0.0, "Sem meta definida"]]

    examples.each { |value, target, percentage, text| expect_funding_progress(value, target, percentage, text) }
  end

  it "renders descriptive aria labels and accepts caller classes" do
    render_inline(described_class.new(kind: "physical", value: 62, class: "max-w-md"))

    expect(page).to have_css("div.max-w-md")
    expect(page.find("[role='progressbar']")["aria-label"]).to eq("Avanço físico da obra")

    render_inline(described_class.new(kind: "funding", value: 1, target: 2))

    expect(page.find("[role='progressbar']")["aria-label"]).to eq("Recursos arrecadados")
  end

  it "rejects a progress kind outside the component contract" do
    expect { described_class.new(kind: "political", value: 20) }.to raise_error(ArgumentError, /invalid kind/)
  end

  private

  def expect_physical_progress(value)
    render_inline(described_class.new(kind: "physical", value: value))
    expected = value.clamp(0, 100)
    expect_progress_value(expected)
    expect(page).to have_text("#{expected}%")
  end

  def expect_funding_progress(value, target, percentage, text)
    render_inline(described_class.new(kind: "funding", value: value, target: target))
    expect_funding_value(percentage)
    expect(page).to have_text(text)
    expect(page).to have_css("[role='progressbar'] .bg-accent")
  end

  def expect_progress_value(expected)
    expect(page.find("[role='progressbar']")["aria-valuenow"].to_f).to eq(expected)
  end

  def expect_funding_value(expected)
    expect(page.find("[role='progressbar']")["aria-valuenow"].to_f).to be_within(0.01).of(expected)
  end
end
