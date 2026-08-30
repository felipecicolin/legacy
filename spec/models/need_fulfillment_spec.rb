# frozen_string_literal: true

require "rails_helper"

# O abatimento e a trava. É a parte genuinamente difícil da #33, e o que estes
# exemplos prendem não é o número final: é o MECANISMO que impede duas
# alocações simultâneas de caberem na mesma vaga.
RSpec.describe NeedFulfillment do
  let(:need) { create(:need, quantity: 3) }

  describe "the three polymorphic sources" do
    # Uma necessidade de material é abatida por doação, a de recurso por
    # contribuição, a de mão de obra por alocação. Um mecanismo, três origens —
    # senão cada espécie ganha a sua própria contabilidade e elas divergem.
    it "counts an allocation" do
      need.fulfill(source: create(:assignment), quantity: 2)

      expect(need.reload.fulfilled_quantity).to eq(2)
    end

    # As outras duas origens chegam com #39; o que o mecanismo precisa provar
    # hoje é que ele não conhece o tipo da origem.
    it "counts a source of any type at all" do
      need.fulfill(source: create(:deployment), quantity: 1)

      expect(need.reload.fulfilled_quantity).to eq(1)
    end

    it "keeps one fulfillment per source" do
      source = create(:assignment)
      need.fulfill(source: source, quantity: 1)

      expect { need.fulfill(source: source, quantity: 1) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "the ceiling" do
    it "refuses more than what is left" do
      need.fulfill(source: create(:assignment), quantity: 2)

      expect { need.fulfill(source: create(:assignment), quantity: 2) }
        .to raise_error(ActiveRecord::RecordInvalid, /passa do que ainda falta/)
    end

    it "accepts exactly what is left" do
      need.fulfill(source: create(:assignment), quantity: 2)

      expect { need.fulfill(source: create(:assignment), quantity: 1) }
        .to change { need.reload.need_status }.to("fulfilled")
    end

    # A validação pega o caminho normal; o CHECK é a rede para seed, console e
    # SQL cru — e é ele que sobra se alguém abater sem passar por `fulfill`.
    it "refuses an overflow written straight to the database" do
      corrupt = "update needs set fulfilled_quantity = 9 where id = #{need.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /fulfilled_within_quantity/)
    end
  end

  # A trava, e é ela que impede a corrida. O repositório não escreve spec com
  # `Thread.new` — o `ThreadSafety/NewThread` reprova, e um teste de corrida
  # que depende de escalonamento é intermitente por construção. O que dá para
  # provar de forma determinística é o MECANISMO: que a leitura da quantidade
  # acontece com a linha travada.
  describe "the lock that makes the race impossible" do
    def statements(&)
      collected = []
      collect = ->(*, payload) { collected << payload[:sql] }
      ActiveSupport::Notifications.subscribed(collect, "sql.active_record", &)
      collected
    end

    it "locks the need row before reading how much is left" do
      sql = statements { need.fulfill(source: create(:assignment), quantity: 1) }

      expect(sql.grep(/FOR UPDATE/)).not_to be_empty
    end

    it "locks before releasing too, so a cancellation cannot race an allocation" do
      assignment = create(:assignment)
      need.fulfill(source: assignment, quantity: 1)
      sql = statements { need.release(source: assignment) }

      expect(sql.grep(/FOR UPDATE/)).not_to be_empty
    end

    # O que a trava garante em sequência, e que é o mesmo que ela garante sob
    # concorrência: a segunda leitura já enxerga o que a primeira gravou.
    it "sees what the previous fulfillment wrote" do
      single = create(:need, quantity: 1)
      single.fulfill(source: create(:assignment), quantity: 1)

      expect { single.fulfill(source: create(:assignment), quantity: 1) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "releasing" do
    it "gives the quantity back and reopens the need" do
      assignment = create(:assignment)
      need.fulfill(source: assignment, quantity: 3)

      expect { need.release(source: assignment) }.to change { need.reload.need_status }
        .from("fulfilled").to("open")
    end

    it "leaves the other sources counted" do
      kept = create(:assignment)
      released = create(:assignment)
      need.fulfill(source: kept, quantity: 1)
      need.fulfill(source: released, quantity: 1)

      expect { need.release(source: released) }.to change { need.reload.fulfilled_quantity }.from(2).to(1)
    end
  end

  it "refuses a quantity of zero" do
    expect(build(:need_fulfillment, need: need, quantity: 0)).not_to be_valid
  end

  it "refuses a quantity of zero in the database too" do
    fulfillment = create(:need_fulfillment, need: need)
    corrupt = "update need_fulfillments set quantity = 0 where id = #{fulfillment.id}"

    expect { described_class.connection.execute(corrupt) }
      .to raise_error(ActiveRecord::StatementInvalid, /quantity_is_positive/)
  end
end
