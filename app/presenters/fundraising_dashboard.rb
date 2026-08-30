# frozen_string_literal: true

# Fachada de leitura do painel institucional de arrecadação.
class FundraisingDashboard
  def initialize(context)
    @context = context
  end

  delegate :visibility, to: :@context

  delegate :simulated?, to: :"Payments::Gateway"

  def channels
    @channels ||= FundraisingChannels.new
  end

  def cash_total_cents = channels.all.sum(&:cash_cents)

  def in_kind_total_cents = channels.all.sum(&:in_kind_cents)

  def campaigns
    @campaigns ||= FundraisingCampaigns.new(visibility)
  end

  def subscriptions
    @subscriptions ||= FundraisingSubscriptions.new
  end

  def in_kind
    @in_kind ||= FundraisingInKind.new
  end

  def disbursements
    @disbursements ||= FundraisingDisbursements.new(visibility)
  end

  def trend
    @trend ||= FundraisingTrend.new
  end
end
