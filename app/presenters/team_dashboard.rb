# frozen_string_literal: true

# A visão do time da obra: cronograma, orçamento, arrecadação e entrega
# prevista, obra por obra. Ver docs/team-dashboard.md.
class TeamDashboard
  # O que uma obra responde ao time, já somado. Objeto de valor porque a view
  # lê seis números e um hash que perde uma chave vira `nil` em tela.
  Board = Data.define(:project, :role, :budgeted_cents, :spent_cents,
                      :raised_cents, :goal_cents)

  def initialize(profile, context)
    @profile = profile
    @context = context
  end

  delegate :visibility, to: :@context

  def participations
    @participations ||= @profile.project_participations.effective.includes(project: :ngo)
  end

  def on_a_team? = participations.any?

  def boards
    @boards ||= reachable.map do |participation|
      project = participation.project
      Board.new(project: project, role: participation.participation_role_label,
                **project.budget_figures)
    end
  end

  private

  # A obra que o leitor não alcança não aparece nem pelo próprio vínculo: o
  # nível da obra vale inclusive para quem está nela.
  def reachable
    visible = Project.visible_to(visibility).select(:id)
    participations.where(project_id: visible)
  end
end
