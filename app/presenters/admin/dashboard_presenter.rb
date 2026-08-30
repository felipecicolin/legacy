# frozen_string_literal: true

module Admin
  # O que a tela do painel do administrador precisa saber, sem saber HTML.
  # Cada método dispara um número fixo de consultas, não uma por obra — é o
  # que sustenta "contagem de query constante" (issue #50).
  #
  # Tile de arrecadação e alerta de assinatura/candidatura ficam de fora de
  # propósito: dependem de `Campaign` (#39) e `Candidacy`/`Subscription`
  # (#33 parte 2, #39), que ainda não existem.
  class DashboardPresenter
    include Rails.application.routes.url_helpers

    I18N_SCOPE = "admin.dashboard.show"
    PAUSED_ALERT_THRESHOLD = 15.days
    NEEDED_BY_ALERT_WINDOW = 7.days
    RECENT_ACTIVITY_LIMIT = 5

    Alert = Data.define(:severity, :title, :href)
    Tile = Data.define(:label, :value, :icon, :pending)
    AlertSpec = Data.define(:severity, :key, :href)
    private_constant :AlertSpec

    # Nem esta nem `raised_this_month_tile`/`alert_if_any` dependem do
    # `@visibility` de uma instância (contagem de voluntário não é dado
    # sensível, valor de arrecadação ainda não existe, e montar um alerta é
    # decisão sobre a contagem que o chamador já filtrou) — por isso vivem
    # como método de classe, em vez de fingir precisar de estado que não têm.
    def self.active_volunteers_tile
      count = VolunteerEngagement.effective.count
      Tile.new(label: I18n.t(:active_volunteers, scope: I18N_SCOPE), value: count.to_s, icon: "users",
               pending: false)
    end

    def self.raised_this_month_tile
      Tile.new(label: I18n.t(:raised_this_month, scope: I18N_SCOPE), value: nil, icon: "chart-bar", pending: true)
    end

    def self.alert_if_any(scope, spec)
      count = scope.count
      return [] unless count.positive?

      [Alert.new(severity: spec.severity, title: I18n.t(spec.key, scope: I18N_SCOPE, count: count), href: spec.href)]
    end

    def initialize(visibility)
      @visibility = visibility
    end

    def alerts
      urgent_project_alerts + paused_project_alerts + critical_need_alerts
    end

    def tiles
      [active_projects_tile, people_served_tile,
       self.class.active_volunteers_tile, self.class.raised_this_month_tile]
    end

    # `order(status: :desc)` funciona porque `Project::STATUSES` já ordena os
    # cinco estados por urgência crescente (surveying=0 … urgent=3); não é
    # coincidência, é o motivo de a issue #8 ter fixado essa ordem.
    def active_projects
      @active_projects ||= Project.visible_to(@visibility).where.not(status: :completed)
                                  .includes(:mission_base, :project_photos).order(status: :desc)
    end

    def country_rollup
      @country_rollup ||= AnonymizedRollup.new(@visibility).by_region
    end

    def recent_activity
      @recent_activity ||= ProgressReport.approved.joins(:project).merge(Project.visible_to(@visibility))
                                         .includes(:project, :reported_by, :project_photos)
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

    def active_projects_tile
      Tile.new(label: I18n.t(:active_projects, scope: I18N_SCOPE), value: active_projects.count.to_s,
               icon: "hard-hat", pending: false)
    end

    def people_served_tile
      served = MissionBase.visible_to(@visibility).sum(:people_served)
      Tile.new(label: I18n.t(:people_served, scope: I18N_SCOPE), value: served.to_s, icon: "users", pending: false)
    end
  end
end
