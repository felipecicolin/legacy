# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthLayoutComponent, type: :component do
  let(:placeholder) { "Espaço reservado para a imagem da tela de acesso" }

  it "renders the form column with the main landmark and the brand" do
    render_inline(described_class.new) { "Formulário" }

    expect(page).to have_css("main#main-content", text: "Formulário")
    expect(page).to have_css("header img[alt='Legacy']")
  end

  # O formulário vem antes do painel no DOM justamente para que teclado e
  # leitor de tela não atravessem a ilustração — só a pintura o joga para a
  # direita. Um `flex-row-reverse` perdido inverteria as duas coisas de uma vez
  # e nada mais reprovaria.
  it "keeps the form ahead of the illustration in the DOM" do
    render_inline(described_class.new) { "Formulário" }

    expect(page).to have_css("div.flex-row-reverse > *:first-child main#main-content")
    expect(page).to have_css("div.flex-row-reverse > aside:last-child")
  end

  it "falls back to the image placeholder when no illustration is given" do
    render_inline(described_class.new) { "Formulário" }

    expect(page).to have_css("aside .bg-accent.text-accent-foreground")
    expect(page).to have_text(placeholder)
  end

  it "hands the panel over to the illustration slot when there is one" do
    render_with_illustration

    expect(page).to have_css("aside", text: "Foto")
    expect(page).to have_no_text(placeholder)
  end

  it "merges the caller's classes with its own" do
    render_inline(described_class.new(class: "bg-card")) { "Formulário" }

    expect(page).to have_css("div.bg-card.flex.min-h-screen")
    expect(page).to have_no_css("div.bg-background")
  end

  private

  def render_with_illustration
    render_inline(described_class.new) do |auth|
      auth.with_illustration { "Foto" }
      "Formulário"
    end
  end
end
