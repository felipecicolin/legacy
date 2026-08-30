# frozen_string_literal: true

# A candidatura aprovada virando alocação, e a alocação abatendo a necessidade.
# Sem esse fechamento a necessidade fica aberta para sempre e a plataforma
# mente sobre o que ainda falta. Ver docs/mobilization.md.
class Assignment < ApplicationRecord
  # Papel de quem chega por alocação. É `volunteer` porque a alocação nasce de
  # uma candidatura a uma necessidade — quem coordena a obra entra por outro
  # caminho, e não por candidatura.
  PARTICIPATION_ROLE = :volunteer

  belongs_to :candidacy
  belongs_to :need
  has_one :need_fulfillment, as: :source, dependent: :destroy

  enum :assignment_status, { confirmed: 0, in_progress: 1, completed: 2, cancelled: 3 },
       validate: true, prefix: true

  validates :candidacy_id, uniqueness: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :starts_on, presence: true
  validate :ends_after_it_starts
  validate :candidacy_belongs_to_the_need

  after_create :take_the_slot
  after_update :give_the_slot_back, if: :saved_change_to_assignment_status?
  after_destroy :give_the_slot_back

  def assignment_status_label
    I18n.t(assignment_status, scope: :assignment_statuses)
  end

  private

  # Um caminho só: alocar abate a necessidade E põe a pessoa na equipe da obra.
  # Dois caminhos separados produziriam voluntário alocado que não aparece na
  # equipe — e ninguém descobriria até a obra começar.
  def take_the_slot
    need.fulfill(source: self, quantity: quantity)
    join_the_project
  end

  def give_the_slot_back
    return unless destroyed? || assignment_status_cancelled?

    need.release(source: self)
    leave_the_project
  end

  # Necessidade de base não tem obra, e aí não há equipe em que entrar — o caso
  # normal da necessidade que existe sem obra ativa.
  #
  # `unless scope`, e NÃO `if scope.blank?`: uma relation vazia é `blank?`, e a
  # relation aqui é vazia justamente no caso comum — a pessoa ainda não está na
  # equipe. Com `blank?` a participação nunca era criada, e nada dava erro.
  def join_the_project
    scope = participation_scope
    return unless scope

    scope.find_or_create_by!(participation_role: PARTICIPATION_ROLE) do |participation|
      participation.started_on = starts_on
      participation.participation_status = :active
    end
  end

  def leave_the_project
    scope = participation_scope
    return unless scope

    scope.where(participation_role: PARTICIPATION_ROLE).destroy_all
  end

  # `nil` quando falta obra ou candidato individual: candidatura de grupo não
  # produz participação, porque quem participa da obra é pessoa.
  #
  # `candidacy.profile` sem `&.`: a candidatura é obrigatória, e este método só
  # roda em callback — num registro que já passou pelas validações.
  def participation_scope
    profile = candidacy.profile
    return if need.project_id.blank? || profile.blank?

    ProjectParticipation.where(project_id: need.project_id, profile_id: profile.id)
  end

  def ends_after_it_starts
    return if ends_on.blank? || starts_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, :before_start)
  end

  def candidacy_belongs_to_the_need
    return if candidacy.blank? || candidacy.need_id == need_id

    errors.add(:candidacy, :other_need)
  end
end
