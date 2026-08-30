# frozen_string_literal: true

# Assinaturas, receita recorrente normalizada para mês e benefícios pendentes.
# Nenhum assinante é nomeado no painel administrativo de arrecadação.
class FundraisingSubscriptions
  INTERVAL_MONTHS = { "monthly" => 1, "quarterly" => 3, "yearly" => 12 }.freeze
  RECURRING_STATUSES = %w[active past_due].freeze
  Row = Data.define(:plan_key, :amount_cents, :interval_label, :status, :status_label,
                    :next_charge_on, :monthly_amount_cents)
  Benefit = Data.define(:kind, :kind_label, :due_on, :status, :status_label)

  def self.monthly_amount(plan)
    plan.amount_cents / INTERVAL_MONTHS.fetch(plan.interval)
  end

  def rows
    @rows ||= Subscription.includes(:subscription_plan).order(:status, :next_charge_on).map do |subscription|
      plan = subscription.subscription_plan
      Row.new(plan_key: plan.key, amount_cents: plan.amount_cents, interval_label: plan.interval_label,
              status: subscription.status, status_label: I18n.t(subscription.status, scope: :statuses),
              next_charge_on: subscription.next_charge_on,
              monthly_amount_cents: self.class.monthly_amount(plan))
    end
  end

  def monthly_recurring_cents
    rows.select { |row| RECURRING_STATUSES.include?(row.status) }.sum(&:monthly_amount_cents)
  end

  def benefits
    @benefits ||= SubscriberBenefit.where(status: :pending).order(:due_on).limit(12).map do |benefit|
      Benefit.new(kind: benefit.kind, kind_label: I18n.t(benefit.kind, scope: :kinds), due_on: benefit.due_on,
                  status: benefit.status, status_label: I18n.t(benefit.status, scope: :statuses))
    end
  end
end
