# frozen_string_literal: true

# O vínculo da pessoa com a organização — "esta pessoa é voluntária, de que
# tipo, em que área". É camada diferente de `ProjectParticipation`, que é a
# presença dela numa obra específica.
#
# As duas existem porque dois dos quatro modelos do material institucional
# **não passam por obra nenhuma**: quem trabalha fixo no escritório e quem faz
# divulgação são voluntários ativos com zero participações. Fundir as duas
# camadas apagaria exatamente esse caso. Ver docs/mobilization.md.
class VolunteerEngagement < ApplicationRecord
  # O modelo corporativo é o único que vem em bloco, e é o único que exige
  # grupo — os outros três são pessoas se voluntariando por conta própria.
  GROUP_MODEL = "corporate"

  belongs_to :profile, inverse_of: :volunteer_engagements
  belongs_to :organization, optional: true
  belongs_to :volunteer_group, optional: true

  enum :engagement_model,
       { office_fixed: 0, project_spot: 1, project_permanent: 2, corporate: 3 },
       validate: true, prefix: true

  # `communication` é a "divulgação" do material, e ela é engajamento legítimo:
  # aparece nas mesmas listagens que a construção, sem segunda classe.
  enum :engagement_area,
       { construction: 0, office: 1, communication: 2, education: 3, logistics: 4 },
       validate: true, prefix: true

  enum :engagement_status,
       { applied: 0, screening: 1, active: 2, paused: 3, completed: 4 },
       validate: true, prefix: true

  scope :effective, -> { engagement_status_active }

  validates :started_on, presence: true
  validates :weekly_hours, numericality: { only_integer: true, in: 1..168 }, allow_nil: true
  validate :ends_after_it_starts
  validate :group_matches_the_model

  def engagement_model_label
    I18n.t(engagement_model, scope: :engagement_models)
  end

  def engagement_area_label
    I18n.t(engagement_area, scope: :engagement_areas)
  end

  def engagement_status_label
    I18n.t(engagement_status, scope: :engagement_statuses)
  end

  # Quem trabalha no escritório é voluntário e não vai a obra nenhuma. A
  # pergunta existe para a tela não oferecer candidatura de obra a quem o
  # engajamento não coloca em campo.
  def works_on_projects? = engagement_model_project_spot? || engagement_model_project_permanent?

  private

  # Nos dois sentidos, como no `skill` da necessidade: `corporate` sem grupo é
  # candidatura em bloco sem bloco, e grupo num modelo individual é vínculo que
  # ninguém coordena.
  # Pelo OBJETO, e não por `volunteer_group_id`: num engajamento ainda não
  # salvo a associação já está montada e o id ainda é nulo.
  def group_matches_the_model
    return if engagement_model_corporate? == volunteer_group.present?

    errors.add(:volunteer_group, engagement_model_corporate? ? :blank : :present)
  end

  def ends_after_it_starts
    return if ended_on.blank? || started_on.blank? || ended_on >= started_on

    errors.add(:ended_on, :before_start)
  end
end
