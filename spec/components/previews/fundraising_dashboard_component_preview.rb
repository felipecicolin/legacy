# frozen_string_literal: true

class FundraisingDashboardComponentPreview < ViewComponent::Preview
  def default
    render(FundraisingDashboardComponent.new(presenter: presenter))
  end

  private

  def presenter
    Presenter.new(channels: Channels.new, campaigns: Campaigns.new,
                  subscriptions: Subscriptions.new, in_kind: InKind.new,
                  disbursements: Disbursements.new, trend: Trend.new)
  end

  Presenter = Data.define(:channels, :campaigns, :subscriptions, :in_kind, :disbursements, :trend) do
    def cash_total_cents = 127_500

    def in_kind_total_cents = 48_000
  end

  class Channels
    Channel = Data.define(:key, :cash_cents, :in_kind_cents)

    def all
      [
        Channel.new(key: :one_off, cash_cents: 42_000, in_kind_cents: 0),
        Channel.new(key: :recurring, cash_cents: 35_500, in_kind_cents: 0),
        Channel.new(key: :in_kind, cash_cents: 0, in_kind_cents: 48_000),
        Channel.new(key: :event_store, cash_cents: 50_000, in_kind_cents: 0),
      ]
    end
  end

  class Campaigns
    def rows
      [FundraisingCampaigns::Row.new(title: "Centro comunitário", ngo_name: "Base Esperança",
                                     goal_cents: 200_000, cash_raised_cents: 127_500,
                                     in_kind_raised_cents: 48_000, progress_percentage: 63,
                                     ends_on: Date.current + 30.days, status: "active", status_label: "Ativa")]
    end

    def hidden
      FundraisingCampaigns::Aggregate.new(count: 0, goal_cents: 0, cash_raised_cents: 0,
                                          in_kind_raised_cents: 0)
    end
  end

  class Subscriptions
    def rows
      [FundraisingSubscriptions::Row.new(plan_key: "apoiador", amount_cents: 5_000,
                                         interval_label: "Mensal", status: "active", status_label: "Ativa",
                                         next_charge_on: Date.current + 10.days, monthly_amount_cents: 5_000)]
    end

    def monthly_recurring_cents = 5_000

    def benefits
      [FundraisingSubscriptions::Benefit.new(kind: "monthly_report", kind_label: "Relatório mensal",
                                             due_on: Date.current + 5.days, status: "pending",
                                             status_label: "Pendente")]
    end
  end

  class InKind
    def material_cents = 32_000

    def intelligence_cents = 16_000

    def rows
      [FundraisingInKind::Row.new(title: "Cimento", category: "material", category_label: "Material",
                                  estimated_value_cents: 32_000, status: "accepted", status_label: "Aceita",
                                  expected_on: Date.current + 12.days, delivered_on: nil)]
    end
  end

  class Disbursements
    Row = FundraisingDisbursements::Row

    def scheduled_cents = 18_400

    def executed_cents = 36_800

    def rows
      [Row.new(reference: "REP-001", description: "Primeira etapa", ngo_name: "Base Esperança",
               amount_cents: 18_400, currency: "BRL", scheduled_on: Date.current,
               executed_on: nil, status: "scheduled", status_label: "Agendado")]
    end

    def hidden
      FundraisingDisbursements::Aggregate.new(count: 0, amount_cents: 0)
    end
  end

  class Trend
    def points
      FundraisingTrend::Point.new(month: Date.current, label: "08/2026",
                                  amounts: { one_off: 42_000, recurring: 35_500,
                                             in_kind: 48_000, event_store: 50_000 })
                             .then { |point| Array.new(FundraisingTrend::MONTH_COUNT, point) }
    end
  end
end
