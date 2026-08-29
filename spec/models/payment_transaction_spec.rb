# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentTransaction do
  describe "validations" do
    it { is_expected.to validate_presence_of(:reference) }
    it { is_expected.to validate_presence_of(:provider_reference) }
    it { is_expected.to validate_numericality_of(:amount_cents).only_integer.is_greater_than(0) }

    it "refuses a currency that is not an ISO 4217 code" do
      expect(build(:payment_transaction, currency: "reais")).not_to be_valid
    end

    it "accepts an ISO 4217 code" do
      expect(build(:payment_transaction, currency: "USD")).to be_valid
    end
  end

  describe "the origin stamp" do
    # A marca nasce ligada: numa instalação de demonstração o silêncio tem de
    # errar para o lado de marcar demais.
    it "defaults to simulated" do
      expect(described_class.new).to be_simulated
    end

    # Não é um update a ser pego em code review: é uma exceção, em tempo de
    # execução, no lugar onde alguém tentou promover dinheiro de mentira a
    # dinheiro de verdade.
    it "refuses to be rewritten by update" do
      transaction = create(:payment_transaction)

      expect { transaction.update(simulated: false) }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end

    it "keeps the stored value after the attempt" do
      transaction = create(:payment_transaction)

      suppress(ActiveRecord::ReadonlyAttributeError) { transaction.update(simulated: false) }

      expect(transaction.reload).to be_simulated
    end
  end

  describe "the closed vocabularies" do
    it "refuses an operation the contract does not name" do
      expect { build(:payment_transaction, kind: :chargeback) }.to raise_error(ArgumentError)
    end

    it "refuses a status the contract does not name" do
      expect { build(:payment_transaction, status: :approved) }.to raise_error(ArgumentError)
    end
  end

  # A convenção de #59: nenhum valor de enum vai cru para a tela. O spec existe
  # porque a chave é montada em tempo de execução — sem ele, um valor novo no
  # contrato passaria a renderizar "Translation missing" e nada reprovaria.
  describe "enum labels" do
    it "translates every operation the contract declares" do
      labels = Payments::PaymentProvider::OPERATIONS.map do |kind|
        build(:payment_transaction, kind: kind).kind_label
      end

      expect(labels).to all(satisfy { |label| label.present? && label.exclude?("translation missing") })
    end

    it "translates every status the contract declares" do
      labels = Payments::PaymentProvider::STATUSES.map do |status|
        build(:payment_transaction, status: status).status_label
      end

      expect(labels).to all(satisfy { |label| label.present? && label.exclude?("translation missing") })
    end
  end
end
