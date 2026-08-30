# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatCardComponent, type: :component do
  it "puts the label above the number and the unit below it" do
    render_inline(described_class.new(label: "Total aportado", value: "R$ 56.000,00", hint: "no ano"))

    expect(page).to have_css("dt", text: "Total aportado")
    expect(page).to have_css("dd", text: "R$ 56.000,00")
    expect(page).to have_css("dd", text: "no ano")
  end

  # Número em coluna precisa de figura tabular: sem ela os dígitos dançam de
  # uma linha para a outra e a comparação vertical deixa de funcionar.
  it "renders the number with tabular figures" do
    render_inline(described_class.new(label: "Obras", value: "4"))

    expect(page).to have_css("dd.tabular-nums", text: "4")
  end

  it "leaves out the hint line when there is no unit to explain" do
    render_inline(described_class.new(label: "Obras", value: "4"))

    expect(page).to have_css("dd", count: 1)
  end

  it "accepts classes from the caller" do
    render_inline(described_class.new(label: "Obras", value: "4", class: "col-span-2"))

    expect(page).to have_css("div.col-span-2")
  end
end
