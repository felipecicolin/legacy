# frozen_string_literal: true

require "rails_helper"

RSpec.describe ToastComponent, type: :component do
  it "rejects an unknown severity" do
    expect { described_class.new(severity: :info, message: "texto") }
      .to raise_error(ArgumentError, /invalid severity/)
  end

  it "renders an alert with an alert role" do
    render_inline(described_class.new(severity: :alert, message: "Falha"))

    expect(page).to have_css('[role="alert"]', text: "Falha")
    expect(page).to have_css(".bg-destructive-soft")
  end

  it "renders a notice with a status role" do
    render_inline(described_class.new(severity: :notice, message: "Tudo certo"))

    expect(page).to have_css('[role="status"]', text: "Tudo certo")
    expect(page).to have_css(".bg-success-soft")
  end

  it "merges caller classes" do
    render_inline(described_class.new(severity: :notice, message: "Tudo certo", classes: "px-6"))

    expect(page).to have_css(".px-6:not(.px-3)")
  end
end
