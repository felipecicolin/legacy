# frozen_string_literal: true

# O vínculo entre uma pessoa e uma organização, com papel.
#
# Papel é contexto, e é por isso que ele mora aqui e não numa coluna em
# `profiles`: a mesma pessoa é dona de uma igreja e representante de uma
# empresa sem que nada nela mude. Ver docs/organizations.md.
class Membership < ApplicationRecord
  belongs_to :profile
  belongs_to :organization

  enum :role, { owner: 0, admin: 1, member: 2, representative: 3 }, validate: true

  # `accepted_at` nulo é convite pendente. Os dois escopos existem porque a
  # pergunta "quem manda nesta organização" e a pergunta "quem foi convidado"
  # são consultas diferentes, e nenhuma delas deve ser escrita à mão.
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :pending, -> { where(accepted_at: nil) }

  # Quem garante um vínculo por par é o índice único; a validação existe para a
  # segunda tentativa virar erro de formulário, e porque o
  # `database_consistency` cobra um validador correspondente ao índice.
  validates :profile_id, uniqueness: { scope: :organization_id }

  validate :organization_keeps_an_owner, on: :update

  # `prepend: true` para rodar antes do `dependent:` de qualquer associação que
  # este registro venha a ter: a recusa tem de acontecer antes de qualquer
  # efeito colateral, não depois.
  before_destroy :refuse_to_remove_the_last_owner, prepend: true

  def role_label
    I18n.t(role, scope: :roles)
  end

  def accepted? = accepted_at.present?

  def pending? = !accepted?

  # Convite pendente não concede permissão nenhuma: enquanto `accepted_at` for
  # nulo, a pergunta "qual o papel desta pessoa nesta organização" responde
  # nada. É este método — e não `role` — que as policies (#23) consultam.
  def effective_role = accepted? ? role : nil

  private

  def other_owners
    organization.memberships.owner.where.not(id: id)
  end

  # A organização é destruída inteira: aí a última posse vai junto, e recusar
  # seria impedir de apagar a própria coisa que o dono possuía.
  #
  # A checagem é pela classe que destrói, e não por `destroyed_by_association`
  # presente: a cascata que vem de `Profile` também preenche esse atributo, e
  # tratá-la como isenta apagaria em silêncio o único dono de uma organização
  # que continua existindo. Apagar a pessoa nesse caso reprova, de propósito.
  def destroyed_with_the_organization?
    destroyed_by_association&.active_record == Organization
  end

  def refuse_to_remove_the_last_owner
    return if destroyed_with_the_organization?
    return unless owner? && other_owners.none?

    errors.add(:base, :last_owner)
    throw(:abort)
  end

  # A outra metade da mesma invariante: rebaixar o último dono deixa a
  # organização sem ninguém que responda por ela, exatamente como removê-lo.
  # Aqui é validação, e não callback, porque a troca de papel é uma gravação
  # comum e o resultado tem de ser erro de formulário.
  def organization_keeps_an_owner
    return unless role_changed? && role_was == "owner"
    return unless other_owners.none?

    errors.add(:base, :last_owner)
  end
end
