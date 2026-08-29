# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::Result do
  it "keeps what the provider answered" do
    result = described_class.new(status: :succeeded, reference: "SIM-doacao-1",
                                 processed_at: Time.current, failure_reason: nil)

    expect(result.status).to eq(:succeeded)
    expect(result.reference).to eq("SIM-doacao-1")
  end

  # Pendência e recusa carregam informação diferente, e o padrão evita que quem
  # devolve uma pendência precise escrever `processed_at: nil` para dizer "não
  # foi processado".
  it "treats the timestamp and the reason as optional" do
    result = described_class.new(status: :pending, reference: "SIM-doacao-1")

    expect(result.processed_at).to be_nil
    expect(result.failure_reason).to be_nil
  end

  # O provedor que inventa vocabulário morre na fronteira, com o valor na
  # mensagem — e não vira linha inválida numa tabela que o enum recusa depois,
  # longe de quem escreveu o provedor.
  it "refuses a status outside the contract" do
    expect { described_class.new(status: :approved, reference: "X-1") }
      .to raise_error(ArgumentError, /unknown status :approved/)
  end
end
