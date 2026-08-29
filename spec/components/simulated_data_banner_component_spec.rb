# frozen_string_literal: true

require "rails_helper"

RSpec.describe SimulatedDataBannerComponent, type: :component do
  it "warns that the numbers on the screen are not real" do
    render_inline(described_class.new)

    expect(page).to have_css("[role='status']", text: /simulado/i)
  end

  it "merges the caller's layout classes with its own" do
    render_inline(described_class.new(classes: "container mx-auto"))

    expect(page).to have_css(".container.mx-auto.bg-warning-soft")
  end

  # O outro lado: numa instalação com provedor de verdade o aviso some sozinho,
  # sem ninguém lembrar de tirá-lo. Aviso falso custa a mesma confiança que
  # aviso faltando.
  it "says nothing when the provider is not simulated" do
    Rails.application.config.x.payment_provider = AlternativePaymentProvider.new

    render_inline(described_class.new)

    expect(rendered_content).to be_blank
  end
end
