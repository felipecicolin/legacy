# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::Gateway do
  let(:request) { Payments::Request.new(amount_cents: 25_000, currency: "BRL", reference: "doacao-7") }

  describe "#charge" do
    it "records the money as centavos, with the currency beside it" do
      transaction = described_class.new.charge(request)

      expect(transaction.amount_cents).to eq(25_000)
      expect(transaction.currency).to eq("BRL")
    end

    it "records what the provider answered" do
      transaction = described_class.new.charge(request)

      expect(transaction).to be_charge.and be_succeeded
      expect(transaction.provider_reference).to eq("SIM-doacao-7")
      expect(transaction.processed_at).to be_present
    end

    # A marca de origem sai do provedor, não de um `if demo?` no chamador: é
    # por isso que nenhuma tela precisa saber em que instalação está rodando.
    it "stamps the origin the provider declares" do
      expect(described_class.new.charge(request)).to be_simulated
    end

    it "records the reason when the provider refuses" do
      provider = Payments::SimulatedProvider.new(outcome: :refused)

      transaction = described_class.new(provider: provider).charge(request)

      expect(transaction).to be_refused
      expect(transaction.failure_reason).to eq("not_authorized")
    end
  end

  describe "#refund" do
    it "records the operation as its own line" do
      transaction = described_class.new.refund(request)

      expect(transaction).to be_refund
      expect(transaction.provider_reference).to eq("SIM-REF-doacao-7")
    end
  end

  describe "#schedule_recurring" do
    it "records the operation as its own line" do
      transaction = described_class.new.schedule_recurring(request)

      expect(transaction).to be_schedule_recurring
      expect(transaction.provider_reference).to eq("SIM-REC-doacao-7")
    end
  end

  describe "swapping the provider" do
    # A promessa da #38 em um exemplo: outro provedor, nenhuma mudança de
    # modelo, de controller ou de schema. Só a configuração.
    it "goes through whatever config.x.payment_provider holds" do
      Rails.application.config.x.payment_provider = AlternativePaymentProvider.new

      transaction = described_class.new.charge(request)

      expect(transaction.provider_reference).to eq("ALT-doacao-7")
      expect(transaction).not_to be_simulated
    end

    it "answers .simulated? from the configured provider" do
      Rails.application.config.x.payment_provider = AlternativePaymentProvider.new

      expect(described_class).not_to be_simulated
    end

    it "is simulated while the simulator is the one configured" do
      expect(described_class).to be_simulated
    end
  end
end
