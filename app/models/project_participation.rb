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

  enum :role, { coordinator: 0, technical_lead: 1, volunteer: 2, local_host: 3, observer: 4 },
       validate: true, prefix: true

  # `invited` não concede permissão nenhuma — é convite, não vínculo. Mesma
  # decisão do `accepted_at` de `Membership`.
  enum :status, { invited: 0, active: 1, completed: 2, withdrawn: 3 }, validate: true, prefix: true

  scope :effective, -> { status_active }
  scope :reporting, -> { effective.where(role: REPORTING_ROLES) }

  # Uma pessoa não some do histórico da obra porque saiu: o índice único é por
  # `[project, profile, role]`, e a validação existe para a segunda tentativa
  # virar erro de formulário em vez de exceção de driver.
  validates :profile_id, uniqueness: { scope: %i[project_id role] }
  validates :started_on, presence: true
  validate :ends_after_it_starts

  def role_label
    I18n.t(role, scope: :participation_roles)
  end

  def status_label
    I18n.t(status, scope: :participation_statuses)
  end

  # Convite pendente não reporta nada, e nem todo vínculo ativo reporta: é este
  # método — e não `role` — que a policy de relatório consulta.
  def may_report? = status_active? && REPORTING_ROLES.include?(role)

  private

  def ends_after_it_starts
    return if ended_on.blank? || started_on.blank? || ended_on >= started_on

    errors.add(:ended_on, :before_start)
  end
end
