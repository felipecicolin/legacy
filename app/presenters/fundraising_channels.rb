# frozen_string_literal: true

# Totais dos quatro canais de entrada. O canal de espécie fica separado do
# caixa mesmo quando os dois representam valor para a mesma campanha.
class FundraisingChannels
  CHANNEL_KEYS = %i[one_off recurring in_kind event_store].freeze
  Channel = Data.define(:key, :cash_cents, :in_kind_cents)

  def all
    queries = self.class
    @all ||= [
      Channel.new(key: :one_off, cash_cents: queries.cash_for(:one_off), in_kind_cents: 0),
      Channel.new(key: :recurring, cash_cents: queries.cash_for(:subscription), in_kind_cents: 0),
      Channel.new(key: :in_kind, cash_cents: 0, in_kind_cents: queries.in_kind_total),
      Channel.new(key: :event_store, cash_cents: queries.cash_for(%i[event store]), in_kind_cents: 0),
    ].freeze
  end

  def fetch(key) = all.find { |channel| channel.key == key }

  def self.cash_for(origins)
    Contribution.confirmed.where(currency: "BRL", origin: origins).sum(:amount_cents)
  end

  def self.in_kind_total
    InKindDonation.accepted_for_total.where(currency: "BRL").sum(:estimated_value_cents)
  end
end
