# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::PaymentProvider do
  # Uma classe anônima que só inclui o contrato: é o provedor que alguém vai
  # escrever amanhã e esquecer de terminar.
  let(:incomplete_provider) { Class.new { include Payments::PaymentProvider }.new }
  let(:request) { Payments::Request.new(amount_cents: 1_000, currency: "BRL", reference: "doacao-1") }

  describe "the unimplemented contract" do
    it "refuses to answer whether the money is simulated" do
      expect { incomplete_provider.simulated? }.to raise_error(NotImplementedError, /simulated\?/)
    end

    it "refuses to charge" do
      expect { incomplete_provider.charge(request) }.to raise_error(NotImplementedError, /charge/)
    end

    it "refuses to refund" do
      expect { incomplete_provider.refund(request) }.to raise_error(NotImplementedError, /refund/)
    end

    it "refuses to schedule a recurring payment" do
      expect { incomplete_provider.schedule_recurring(request) }
        .to raise_error(NotImplementedError, /schedule_recurring/)
    end
  end

  describe "the closed vocabularies" do
    # A tabela deriva os dois enums daqui. Se a lista mudar sem a migration
    # correspondente, é neste par de exemplos que a divergência aparece —
    # antes de um relatório somar errado.
    it "matches the kind column of the ledger" do
      expect(PaymentTransaction.kinds.keys).to match_array(described_class::OPERATIONS.map(&:to_s))
    end

    it "matches the status column of the ledger" do
      expect(PaymentTransaction.statuses.keys).to match_array(described_class::STATUSES.map(&:to_s))
    end
  end
end
