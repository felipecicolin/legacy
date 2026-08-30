# frozen_string_literal: true

require "rails_helper"

STATUS_CASES = {
  "surveying" => { label: "Levantamento", token: "bg-muted" },
  "in_progress" => { label: "Em obra", token: "bg-success" },
  "paused" => { label: "Parada", token: "bg-warning" },
  "urgent" => { label: "Urgente", token: "bg-destructive" },
  "completed" => { label: "Concluída", token: "bg-accent" },
}.freeze

RSpec.describe StatusBadgeComponent, type: :component do
  it "renders each work status with its semantic token and catalog icon" do
    STATUS_CASES.each { |status, data| expect_status(status, data) }
  end

  it "accepts symbols and caller classes" do
    render_inline(described_class.new(status: :urgent, size: :lg, class: "tracking-wide"))

    expect(page).to have_css("span.bg-destructive.tracking-wide")
    expect(page).to have_text("Urgente")
  end

  it "rejects unknown statuses and sizes during construction" do
    expect { described_class.new(status: "unknown") }.to raise_error(ArgumentError, /invalid status/)
    expect { described_class.new(status: "urgent", size: :xl) }.to raise_error(ArgumentError, /invalid size/)
  end

  private

  def expect_status(status, data)
    render_inline(described_class.new(status: status))
    expect(page).to have_css("span.#{data[:token]}", text: data[:label])
    expect(page).to have_css("span.#{data[:token]} svg")
  end

  # O par de cores já era conferido pelo spec de tokens; o que ninguém conferia
  # era se o componente RENDERIZAVA os dois. `text-label` é token do projeto e
  # o merger não o conhece como tamanho — então ele o agrupava com cor e
  # derrubava o `text-success-foreground`, deixando o texto herdar o preto do
  # corpo a 2,77:1. Sem erro em lugar nenhum: só um badge ilegível.
  it "keeps the foreground colour that the size class used to swallow" do
    render_inline(described_class.new(status: :in_progress, size: :sm))

    expect(page).to have_css("span.bg-success.text-success-foreground")
  end
end
