# frozen_string_literal: true

# A leitura completa de uma obra, já com a política de visibilidade aplicada.
# Objetos menores cuidam dos agregados de relatório e de prestação de contas;
# este presenter compõe a API que a tela consome.
class ProjectDetailPresenter
  delegate :title, :code, :status, to: :project
  delegate :progress_report, :reports, :more_reports?, :next_reports_page,
           :report_author, :photo_caption, :reports_page, to: :reports_data
  delegate :funding_value, :funding_target, :funding_currency, :budget_rows,
           :budget_total_cents, to: :finance_data

  attr_reader :project, :context

  def initialize(project, context, reports_page: nil)
    @project = project
    @context = context
    @requested_reports_page = reports_page
  end

  delegate :visibility, to: :context
  def location = project.ngo.location_label(visibility)
  def admin? = context.platform_admin?

  def physical_progress = weighted_progress || project.physical_progress

  def phases
    @phases ||= project.project_phases.to_a
  end
  alias stages phases

  def weighted_progress
    return if phases.empty? || total_phase_weight.zero?

    (phases.sum { |phase| phase.weight * phase.physical_progress }.to_f / total_phase_weight).round
  end

  def phase_contribution(phase)
    return 0 if total_phase_weight.zero?

    phase.weight * phase.physical_progress.to_f / total_phase_weight
  end

  def team_members
    @team_members ||= project.project_participations.effective.includes(:profile).order(:created_at, :id).to_a
  end

  def member_name(member)
    ProfilePresenter.new(member.profile, role_label: member.participation_role_label,
                                         subject: project).name_for(visibility)
  end

  def needs
    @needs ||= project.needs.where(need_status: %i[open partially_fulfilled])
                      .includes(:skill).by_priority.to_a
  end

  private

  attr_reader :requested_reports_page

  def reports_data
    @reports_data ||= ProjectDetailReportsPresenter.new(project, visibility,
                                                        page: requested_reports_page)
  end

  def finance_data
    @finance_data ||= ProjectDetailFinancePresenter.new(project, visibility)
  end

  def total_phase_weight = phases.sum(&:weight)
end
