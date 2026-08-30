# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppShellComponent, type: :component do
  it "renders the application landmarks and the navigation slot" do
    render_shell(navigation: "Link da navegação", content: "Conteúdo principal")

    expect(page).to have_link("Ir para o conteúdo principal", href: "#main-content")
    expect(page).to have_css("aside[data-app-shell-target='drawer']")
    expect(page).to have_css("nav", text: "Link da navegação")
    expect(page).to have_css("main#main-content", text: "Conteúdo principal")
  end

  it "renders with an empty navigation slot and merges caller classes and data" do
    render_inline(described_class.new(class: "bg-card", data: { testid: "shell" })) { "Conteúdo" }

    expect(page).to have_css("div[data-testid='shell'].bg-card")
    expect(page).to have_css("nav")
  end

  it "renders an accessible mobile navigation trigger" do
    render_inline(described_class.new) { "Conteúdo" }

    expect(page).to have_css("button[aria-expanded='false'][aria-controls='app-shell-drawer']")
    expect(page).to have_css("button[data-app-shell-target='toggle'] svg")
    expect(page).to have_css("[data-app-shell-target='overlay'][data-action*='close']")
  end

  private

  def render_shell(navigation: nil, content: "Conteúdo")
    render_inline(described_class.new) do |shell|
      shell.with_navigation { navigation } if navigation
      content
    end
  end
end
