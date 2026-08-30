# frozen_string_literal: true

# Quem vai na equipe, com o papel que exerce na viagem. Papel de viagem não é o
# mesmo que papel na obra: quem lidera a logística do envio pode ser voluntária
# raso no canteiro, e vice-versa.
class DeploymentMember < ApplicationRecord
  belongs_to :deployment
  belongs_to :profile, inverse_of: :deployment_memberships

  enum :member_role, { lead: 0, technical: 1, volunteer: 2, medical: 3, logistics: 4 },
       validate: true, prefix: true

  # `invited` não ocupa vaga — é convite, não confirmação. Mesma decisão do
  # `accepted_at` de `Membership` e do `invited` de `ProjectParticipation`.
  enum :member_status, { invited: 0, confirmed: 1, travelling: 2, returned: 3, cancelled: 4 },
       validate: true, prefix: true

  # Quem já viajou continua ocupando a vaga: a contagem responde "quantos
  # lugares estão comprometidos", e não "quantos ainda vão embarcar".
  scope :confirmed_or_travelling, -> { where(member_status: %i[confirmed travelling returned]) }

  validates :profile_id, uniqueness: { scope: :deployment_id }

  def member_role_label
    I18n.t(member_role, scope: :member_roles)
  end

  def member_status_label
    I18n.t(member_status, scope: :member_statuses)
  end
end
