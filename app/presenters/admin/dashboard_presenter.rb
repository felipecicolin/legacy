# frozen_string_literal: true

module Admin
  # O que a tela do painel do administrador precisa saber, sem saber HTML.
  # Cada método dispara um número fixo de consultas, não uma por obra — é o
  # que sustenta "contagem de query constante" (issue #50).
  class DashboardPresenter
    include Rails.application.routes.url_helpers

    I18N_SCOPE = "admin.dashboard.show"
    PAUSED_ALERT_THRESHOLD = 15.days
    NEEDED_BY_ALERT_WINDOW = 7.days
    STALLED_CANDIDACY_THRESHOLD = 7.days
    RECENT_ACTIVITY_LIMIT = 5

    Alert = Data.define(:severity, :title, :href)
    Tile = Data.define(:label, :value, :icon, :pending)
    CountryAmount = Data.define(:country_name, :amount_label)
    AlertSpec = Data.define(:severity, :key, :href)
    private_constant :AlertSpec

    # Não depende de `@visibility`: montar um alerta é decisão sobre a
    # contagem que o chamador já filtrou, não sobre quem está olhando.
    def self.alert_if_any(scope, spec)
      count = scope.count
      return [] unless count.positive?

      [Alert.new(severity: spec.severity, title: I18n.t(spec.key, scope: I18N_SCOPE, count: count), href: spec.href)]
    end

    # Não depende de `@visibility`: contagem de voluntário não é dado
    # sensível — nenhum model de engajamento carrega `sensitivity_level`.
    def self.active_volunteers_tile
      count = VolunteerEngagement.effective.count
      Tile.new(label: I18n.t(:active_volunteers, scope: I18N_SCOPE), value: count.to_s, icon: "users",
               pending: false)
    end

    # Formatação de moeda não depende de `@visibility` — vive como método de
    # classe pelo mesmo motivo dos dois de cima.
    def self.currency_label(cents)
      ActionController::Base.helpers.number_to_currency(cents / 100.0, locale: :"pt-BR")
    end

    def initialize(visibility)
      @visibility = visibility
    end

    def alerts
      urgent_project_alerts + paused_project_alerts + critical_need_alerts +
        past_due_subscription_alerts + stalled_candidacy_alerts
    end

    def tiles
      [active_projects_tile, people_served_tile, self.class.active_volunteers_tile, raised_this_month_tile]
    end

    # `order(status: :desc)` funciona porque `Project::STATUSES` já ordena os
    # cinco estados por urgência crescente (surveying=0 … urgent=3); não é
    # coincidência, é o motivo de a issue #8 ter fixado essa ordem.
    def active_projects
      @active_projects ||= Project.visible_to(@visibility).where.not(status: :completed)
                                  .includes(:ngo, :campaigns, project_photos: { image_attachment: :blob })
                                  .order(status: :desc)
    end

    # Contagem de obras e progresso físico médio, por região — não dinheiro.
    # `funding_by_country` é a fonte de arrecadação, numa granularidade
    # diferente (país, não região) porque é o que `Campaign.aggregate_by_country`
    # já garante com o próprio piso de k-anonimato — ver docs/visibility.md.
    def country_rollup
      @country_rollup ||= AnonymizedRollup.new(@visibility).by_region
    end

    # `Campaign.aggregate_by_country` (#39) já aplica o piso de k-anonimato
    # (mínimo de 3 campanhas) e já se restringe a campanhas ativas de base
    # ativa — não depende de `@visibility`, porque arrecadação é agregado
    # público por natureza (mesmo dado que a visão do investidor mostra).
    # Aqui só se resolve o nome do país, com uma consulta extra de tamanho
    # constante.
    def funding_by_country
      totals = Campaign.aggregate_by_country
      countries = Country.where(id: totals.keys).index_by(&:id)
      totals.map do |country_id, cents|
        CountryAmount.new(country_name: countries.fetch(country_id).name,
                          amount_label: self.class.currency_label(cents))
      end
    end

    def recent_activity
      @recent_activity ||= ProgressReport.approved.joins(:project).merge(Project.visible_to(@visibility))
                                         .includes(:project, :reported_by, project_photos: { image_attachment: :blob })
                                         .order(reported_on: :desc).limit(RECENT_ACTIVITY_LIMIT)
    end

    private

    def urgent_project_alerts
      spec = AlertSpec.new(severity: "destructive", key: :urgent_project_alert, href: projects_path)
      self.class.alert_if_any(Project.visible_to(@visibility).urgent, spec)
    end

    def paused_project_alerts
      scope = Project.visible_to(@visibility).paused.where(updated_at: ..PAUSED_ALERT_THRESHOLD.ago)
      spec = AlertSpec.new(severity: "warning", key: :paused_project_alert, href: projects_path)
      self.class.alert_if_any(scope, spec)
    end

    def critical_need_alerts
      scope = Need.visible_to(@visibility).urgency_critical.need_status_open
                  .where(needed_by: ..NEEDED_BY_ALERT_WINDOW.from_now.to_date)
      spec = AlertSpec.new(severity: "warning", key: :critical_need_alert, href: needs_path)
      self.class.alert_if_any(scope, spec)
    end

    # Assinatura sem campanha é apoio geral à plataforma, não a uma obra ou
    # base — visível a qualquer staff. Só a assinatura de uma campanha
    # sensível precisa passar por `visible_to`.
    def past_due_subscription_alerts
      visible_campaigns = Campaign.visible_to(@visibility)
      scope = Subscription.past_due.where(campaign_id: nil).or(Subscription.past_due.where(campaign: visible_campaigns))
      spec = AlertSpec.new(severity: "warning", key: :past_due_subscription_alert, href: campaigns_path)
      self.class.alert_if_any(scope, spec)
    end

    def stalled_candidacy_alerts
      scope = Candidacy.candidacy_status_screening.joins(:need).merge(Need.visible_to(@visibility))
                       .where(updated_at: ..STALLED_CANDIDACY_THRESHOLD.ago)
      spec = AlertSpec.new(severity: "warning", key: :stalled_candidacy_alert, href: needs_path)
      self.class.alert_if_any(scope, spec)
    end

    def active_projects_tile
      Tile.new(label: I18n.t(:active_projects, scope: I18N_SCOPE), value: active_projects.count.to_s,
               icon: "hard-hat", pending: false)
    end

    def people_served_tile
      served = Ngo.visible_to(@visibility).sum(:people_served)
      Tile.new(label: I18n.t(:people_served, scope: I18N_SCOPE), value: served.to_s, icon: "users", pending: false)
    end

    def raised_this_month_tile
      cents = Contribution.counted.where(campaign: Campaign.visible_to(@visibility))
                          .where(confirmed_at: Time.current.all_month).sum(:amount_cents)
      Tile.new(label: I18n.t(:raised_this_month, scope: I18N_SCOPE), value: self.class.currency_label(cents),
               icon: "chart-bar", pending: false)
    end
  end
end
