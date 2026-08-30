# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertComponent, type: :component do
  it "renders a warning as a div with the warning token and icon" do
    render_inline(described_class.new(severity: "warning", title: "3 necessidades críticas vencendo"))

    expect(page).to have_css("div[role='alert'].border-warning", text: "3 necessidades críticas vencendo")
    expect(page).to have_css("svg")
  end

  it "renders a destructive alert as a link when href is given" do
    render_inline(described_class.new(severity: "destructive", title: "2 obras urgentes", href: "/obras"))

    expect(page).to have_css("a[role='alert'].border-destructive[href='/obras']", text: "2 obras urgentes")
  end

  it "rejects an unknown severity" do
    expect { described_class.new(severity: "info", title: "x") }.to raise_error(ArgumentError, /invalid severity/)
  end
end
