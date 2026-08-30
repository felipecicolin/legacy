# frozen_string_literal: true

class CandidacyPolicy < ApplicationPolicy
  def show? = own? || context.staff?

  # Candidatura de grupo sai do COORDENADOR do grupo, e não de qualquer membro:
  # inscrever a turma inteira é decisão de quem responde por ela. Um membro
  # comum se candidata por si, pelo caminho individual.
  def create?
    return false unless context.signed_in?
    return coordinates_the_group? if record.volunteer_group

    own?
  end

  def new? = create?

  private

  def own? = record.profile_id.present? && record.profile_id == context.profile&.id

  def coordinates_the_group? = record.volunteer_group.coordinator_id == context.profile&.id
end
