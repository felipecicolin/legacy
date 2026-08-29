# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::Request do
  it "carries the money as centavos, with the currency beside it" do
    request = described_class.new(amount_cents: 25_000, currency: "BRL", reference: "doacao-7")

    expect(request.amount_cents).to eq(25_000)
    expect(request.currency).to eq("BRL")
  end

  # A guarda está aqui, e não só nas validações do rastro, por causa da ordem: o
  # `Gateway` chama o provedor primeiro e grava depois. Um pedido que só reprova
  # no `create!` já passou pelo provedor — num gateway de verdade, isso é
  # dinheiro movido sem linha no banco.
  describe "the money" do
    it "refuses an amount that is not an integer" do
      expect { described_class.new(amount_cents: 250.0, currency: "BRL", reference: "doacao-7") }
        .to raise_error(ArgumentError, /amount_cents/)
    end

    it "refuses an amount that is not positive" do
      expect { described_class.new(amount_cents: 0, currency: "BRL", reference: "doacao-7") }
        .to raise_error(ArgumentError, /amount_cents/)
    end

    it "refuses a currency that is not an ISO 4217 code" do
      expect { described_class.new(amount_cents: 25_000, currency: "brl", reference: "doacao-7") }
        .to raise_error(ArgumentError, /currency/)
    end
  end

  it "refuses a reference that says nothing" do
    expect { described_class.new(amount_cents: 25_000, currency: "BRL", reference: " ") }
      .to raise_error(ArgumentError, /reference/)
  end
end
