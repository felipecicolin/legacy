# frozen_string_literal: true

# Saídas simuladas para as bases, respeitando a visibilidade da ONG e da
# campanha. O que fica fora do alcance vira somente contagem e total agregado.
class FundraisingDisbursements
  Row = Data.define(:reference, :description, :ngo_name, :amount_cents, :currency,
                    :scheduled_on, :executed_on, :status, :status_label)
  Aggregate = Data.define(:count, :amount_cents)

  def initialize(visibility)
    @visibility = visibility
  end

  def rows
    @rows ||= visible_scope.includes(:ngo).order(scheduled_on: :desc).map { |item| self.class.row_for(item) }
  end

  def hidden
    @hidden ||= Aggregate.new(count: hidden_scope.count, amount_cents: hidden_scope.sum(:amount_cents))
  end

  def scheduled_cents = visible_scope.scheduled.sum(:amount_cents)

  def executed_cents = visible_scope.executed.sum(:amount_cents)

  def self.row_for(disbursement)
    Row.new(reference: disbursement.reference, description: disbursement.description,
            ngo_name: disbursement.ngo.name, amount_cents: disbursement.amount_cents,
            currency: disbursement.currency, scheduled_on: disbursement.scheduled_on,
            executed_on: disbursement.executed_on, status: disbursement.status,
            status_label: disbursement.status_label)
  end

  private

  def visible_scope
    Disbursement.visible_to(@visibility)
  end

  def hidden_scope
    Disbursement.hidden_from(@visibility)
  end
end
