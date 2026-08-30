# frozen_string_literal: true

# O envio de equipe. A anotação de origem é explícita: a plataforma auxilia
# **e também envia equipes** — e envio é logística com risco, porque é gente
# viajando para país que pode ser hostil, com prazo e custo.
#
# A base é obrigatória e a obra não: envio para levantar uma base ainda sem
# obra aberta é o caso normal. É a mesma separação que `Need` faz. Ver
# docs/mobilization.md.
class Deployment < ApplicationRecord
  belongs_to :mission_base
  belongs_to :project, optional: true
  has_many :deployment_members, dependent: :destroy
  has_many :members, through: :deployment_members, source: :profile

  enum :deployment_status,
       { planning: 0, open: 1, closed: 2, travelling: 3, completed: 4, cancelled: 5 },
       validate: true, prefix: true

  scope :upcoming, -> { where(departs_on: Date.current..).order(:departs_on) }

  validates :name, presence: true
  validates :departs_on, :returns_on, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :currency, presence: true, length: { is: 3 }
  validates :cost_per_person_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :returns_after_it_departs
  validate :project_belongs_to_the_same_base
  validate :confirmed_members_fit_the_capacity

  def deployment_status_label
    I18n.t(deployment_status, scope: :deployment_statuses)
  end

  def confirmed_members = deployment_members.confirmed_or_travelling

  def seats_left = capacity && (capacity - confirmed_members.count)

  def to_s = name

  private

  def returns_after_it_departs
    return if returns_on.blank? || departs_on.blank? || returns_on >= departs_on

    errors.add(:returns_on, :before_start)
  end

  # A mesma incoerência que `Need` recusa: apontar para a base A pela coluna e
  # para a base B pela obra faz os dois rollups discordarem, sem erro nenhum.
  def project_belongs_to_the_same_base
    return unless project
    return if project.mission_base_id == mission_base_id

    errors.add(:project, :other_mission_base)
  end

  # A capacidade é do avião e da casa, não uma sugestão: passar dela é
  # descobrir na véspera que falta cama para duas pessoas.
  def confirmed_members_fit_the_capacity
    return if capacity.blank? || confirmed_members.count <= capacity

    errors.add(:capacity, :exceeded)
  end
end
