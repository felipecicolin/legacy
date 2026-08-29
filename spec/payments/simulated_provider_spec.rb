# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::SimulatedProvider do
  let(:request) { Payments::Request.new(amount_cents: 25_000, currency: "BRL", reference: "doacao-7") }

  it "declares that the money is not real" do
    expect(described_class.new).to be_simulated
  end

  describe "the configured outcome" do
    # Sucesso, pendência, falha e recusa — os quatro sob configuração. Uma demo
    # que só mostra o caminho feliz não prova que a UI trata erro.
    {
      succeeded: [:succeeded, nil],
      pending: [:pending, nil],
      failed: [:failed, "provider_unavailable"],
      refused: [:refused, "not_authorized"],
    }.each do |outcome, (status, failure_reason)|
      it "produces #{outcome}" do
        result = described_class.new(outcome: outcome).charge(request)

        expect(result.status).to eq(status)
        expect(result.failure_reason).to eq(failure_reason)
      end
    end

    it "refuses an outcome outside the contract" do
      expect { described_class.new(outcome: :approved) }.to raise_error(ArgumentError, /unknown outcome/)
    end
  end

  # Determinismo é o que separa uma demo apresentável de uma que falha uma vez
  # a cada dez — e um spec estável de um intermitente.
  # Só o relógio muda entre duas chamadas iguais; o resto é igual por
  # construção, e é isso que o `with(processed_at: nil)` isola.
  it "answers the same thing to the same request" do
    provider = described_class.new(outcome: :refused)
    first = provider.charge(request)
    second = provider.charge(request)

    expect(second.with(processed_at: nil)).to eq(first.with(processed_at: nil))
  end

  describe "the returned reference" do
    it "marks a charge" do
      expect(described_class.new.charge(request).reference).to eq("SIM-doacao-7")
    end

    it "marks a refund" do
      expect(described_class.new.refund(request).reference).to eq("SIM-REF-doacao-7")
    end

    it "marks a recurring schedule" do
      expect(described_class.new.schedule_recurring(request).reference).to eq("SIM-REC-doacao-7")
    end
  end

  describe "the settlement timestamp" do
    it "dates what was processed" do
      expect(described_class.new.charge(request).processed_at).to be_present
    end

    # O que está pendente não tem horário de liquidação: datá-lo faria a tela
    # mostrar uma hora inventada.
    it "leaves what is pending undated" do
      expect(described_class.new(outcome: :pending).charge(request).processed_at).to be_nil
    end
  end
end
