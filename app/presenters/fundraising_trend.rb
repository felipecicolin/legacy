# frozen_string_literal: true

# Série curta para o gráfico do painel. A chave `in_kind` continua no mesmo
# vetor visual, mas não entra no total de dinheiro da apresentação.
class FundraisingTrend
  CHANNEL_KEYS = FundraisingChannels::CHANNEL_KEYS
  MONTH_COUNT = 6
  Point = Data.define(:month, :label, :amounts)
  ORIGIN_CHANNEL = {
    "0" => :one_off,
    "1" => :recurring,
    "2" => :event_store,
    "3" => :event_store,
    "one_off" => :one_off,
    "subscription" => :recurring,
    "event" => :event_store,
    "store" => :event_store,
  }.freeze

  def self.month_for(time)
    time.to_date.beginning_of_month
  end

  def points
    @points ||= months.map do |month|
      Point.new(month: month, label: I18n.l(month, format: "%m/%Y"), amounts: amounts_for(month))
    end
  end

  private

  def months
    @months ||= Array.new(MONTH_COUNT) do |offset|
      Date.current.beginning_of_month << (MONTH_COUNT - 1 - offset)
    end
  end

  def amounts_for(month)
    CHANNEL_KEYS.index_with { |channel| totals.fetch([month, channel], 0) }
  end

  def totals
    @totals ||= Hash.new(0).tap do |values|
      add_contributions(values)
      add_in_kind(values)
    end
  end

  def add_contributions(values)
    contribution_values.each do |origin, cents, created_at|
      values[[self.class.month_for(created_at), ORIGIN_CHANNEL.fetch(origin.to_s)]] += cents
    end
  end

  def add_in_kind(values)
    in_kind_values.each do |cents, created_at|
      values[[self.class.month_for(created_at), :in_kind]] += cents
    end
  end

  def contribution_values
    Contribution.confirmed.where(currency: "BRL", created_at: date_range)
                .pluck(:origin, :amount_cents, :created_at)
  end

  def in_kind_values
    InKindDonation.accepted_for_total.where(currency: "BRL", created_at: date_range)
                  .pluck(:estimated_value_cents, :created_at)
  end

  def date_range
    months.first.beginning_of_day..months.last.end_of_month.end_of_day
  end
end
