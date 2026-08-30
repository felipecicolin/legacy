# frozen_string_literal: true

class ProgressReportPolicy < ApplicationPolicy
  # Quem reporta avanço responde pelo número. Voluntário e observador não
  # entram: relatório é prestação de contas, e a assinatura tem de ter dono.
  # Quem decide é `ProjectParticipation#may_report?`, e não o papel solto —
  # convite pendente não reporta nada.
  def create? = reporting_participation?

  # Correção é relatório novo, então não há `update?` liberado para ninguém: o
  # default de `ApplicationPolicy` recusa, e é o que se quer.
  def show? = context.staff? || participates?

  private

  # Relação vazia, e não `nil`, quando não há perfil: assim as duas perguntas
  # abaixo são consultas comuns em vez de cadeias de `&.` que respondem `nil`
  # onde uma policy tem de responder `false`.
  def participations
    return ProjectParticipation.none if context.profile.blank?

    context.profile.project_participations.where(project_id: record.project_id)
  end

  def participates? = participations.active.exists?

  def reporting_participation? = participations.reporting.exists?
end
