# frozen_string_literal: true

# Quem faz a obra. É aqui que "papel é contexto, não tipo de usuário" fica
# concreto: a mesma pessoa é coordenadora numa obra, voluntária em outra e
# anfitriã local na terceira. Ver docs/field.md.
class ProjectParticipation < ApplicationRecord
  # Quem pode reportar avanço. Voluntário e observador não entram: relatório é
  # prestação de contas, e quem assina responde por ela.
  REPORTING_ROLES = %w[coordinator technical_lead].freeze

  belongs_to :project
  belongs_to :profile, inverse_of: :project_participations

  # Os nomes não são `role` e `status` porque o rótulo de UI sai de `<enum no
  # plural>.<valor>` (docs/i18n.md), e `roles.*` já é o vocabulário de
  # `Membership` — papel numa organização e papel numa obra são coisas
  # diferentes e não dividem balde. Mesma razão de `Organization#organization_kind`.
  enum :participation_role, { coordinator: 0, technical_lead: 1, volunteer: 2, local_host: 3, observer: 4 },
       validate: true

  # `invited` não concede permissão nenhuma — é convite, não vínculo. Mesma
  # decisão do `accepted_at` de `Membership`.
  enum :participation_status, { invited: 0, active: 1, completed: 2, withdrawn: 3 }, validate: true

  scope :effective, -> { active }
  scope :reporting, -> { effective.where(participation_role: REPORTING_ROLES) }

  # Uma pessoa não some do histórico da obra porque saiu: o índice único é por
  # `[project, profile, role]`, e a validação existe para a segunda tentativa
  # virar erro de formulário em vez de exceção de driver.
  validates :profile_id, uniqueness: { scope: %i[project_id participation_role] }
  validates :started_on, presence: true
  validate :ends_after_it_starts

  def participation_role_label
    I18n.t(participation_role, scope: :participation_roles)
  end

  def participation_status_label
    I18n.t(participation_status, scope: :participation_statuses)
  end

  # Convite pendente não reporta nada, e nem todo vínculo ativo reporta: é este
  # método — e não `role` — que a policy de relatório consulta.
  def may_report? = active? && REPORTING_ROLES.include?(participation_role)

  private

  def ends_after_it_starts
    return if ended_on.blank? || started_on.blank? || ended_on >= started_on

    errors.add(:ended_on, :before_start)
  end
end
