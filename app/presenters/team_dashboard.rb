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
    @boards ||= reachable.map { |participation| board_for(participation) }
  end

  private

  # A obra que o leitor não alcança não aparece nem pelo próprio vínculo: o
  # nível da obra vale inclusive para quem está nela.
  def reachable
    visible = Project.visible_to(visibility).select(:id)
    participations.where(project_id: visible)
  end

  def board_for(participation)
    project = participation.project
    Board.new(project: project, role: participation.participation_role_label,
              budgeted_cents: budget_for(project)&.total_cents.to_i,
              spent_cents: spent_for(project), raised_cents: project.campaigns.sum(:raised_cents),
              goal_cents: project.campaigns.sum(:goal_cents))
  end

  # O orçamento aprovado é o que vale; sem ele, o rascunho mais recente é o que
  # o time está montando, e mostrar zero esconderia o trabalho em curso.
  def budget_for(project)
    project.budgets.approved.order(version: :desc).first ||
      project.budgets.order(version: :desc).first
  end

  def spent_for(project)
    project.expenses.where.not(status: :rejected).sum(:amount_cents)
  end
end
