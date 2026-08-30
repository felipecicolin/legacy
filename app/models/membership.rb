# frozen_string_literal: true

# O vínculo entre uma pessoa e uma organização, com papel.
#
# Papel é contexto, e é por isso que ele mora aqui e não numa coluna em
# `profiles`: a mesma pessoa é dona de uma igreja e representante de uma
# empresa sem que nada nela mude. Ver docs/ngos.md.
class Membership < ApplicationRecord
  belongs_to :profile
  belongs_to :ngo

  enum :role, { owner: 0, admin: 1, member: 2, representative: 3 }, validate: true

  # `accepted_at` nulo é convite pendente. Os dois escopos existem porque a
  # pergunta "quem manda nesta organização" e a pergunta "quem foi convidado"
  # são consultas diferentes, e nenhuma delas deve ser escrita à mão.
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :pending, -> { where(accepted_at: nil) }

  # Quem garante um vínculo por par é o índice único; a validação existe para a
  # segunda tentativa virar erro de formulário, e porque o
  # `database_consistency` cobra um validador correspondente ao índice.
  validates :profile_id, uniqueness: { scope: :ngo_id }

  validate :ngo_keeps_an_owner, on: :update

  # `prepend: true` para rodar antes do `dependent:` de qualquer associação que
  # este registro venha a ter: a recusa tem de acontecer antes de qualquer
  # efeito colateral, não depois.
  #
  # O alcance é o de um callback: `delete_all` e SQL cru montam o DELETE sem
  # instanciar o registro, e passam por baixo desta regra. Ver
  # docs/ngos.md.
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

  # Quem fica sem dono é a organização de ORIGEM, e por isso a consulta sai de
  # `ngo_id_was` em vez de `ngo`. Num update que troca de
  # organização, `ngo` já é a de destino: contar os owners de lá
  # deixaria a de origem sem nenhum, em silêncio. Em destroy e em update sem
  # troca os dois valores são o mesmo.
  #
  # De quebra some o `nil` que `ngo` tinha: um PATCH que limpasse
  # `ngo_id` levantava `NoMethodError` aqui — a validação de presença
  # do `belongs_to` registra o erro, mas não interrompe as outras validações.
  def other_owners
    self.class.owner.where(ngo_id: ngo_id_was).where.not(id: id)
  end

  # A organização é destruída inteira: aí a última posse vai junto, e recusar
  # seria impedir de apagar a própria coisa que o dono possuía.
  #
  # A checagem é pela classe que destrói, e não por `destroyed_by_association`
  # presente: a cascata que vem de `Profile` também preenche esse atributo, e
  # tratá-la como isenta apagaria em silêncio o único dono de uma organização
  # que continua existindo. Apagar a pessoa nesse caso reprova, de propósito.
  def destroyed_with_the_ngo?
    destroyed_by_association&.active_record == Ngo
  end

  def refuse_to_remove_the_last_owner
    return if destroyed_with_the_ngo?
    return unless owner? && other_owners.none?

    errors.add(:base, :last_owner)
    throw(:abort)
  end

  # A outra metade da mesma invariante. Um vínculo deixa de ser posse da sua
  # organização de duas formas, e as duas deixam-na sem ninguém que responda
  # por ela, exatamente como removê-lo: ser REBAIXADO e ser MOVIDO para outra
  # organização. A segunda não passa por `role`, então uma guarda que só
  # perguntasse `role_changed?` a deixaria passar inteira.
  #
  # Aqui é validação, e não callback, porque as duas são gravação comum e o
  # resultado tem de ser erro de formulário.
  def ngo_keeps_an_owner
    return unless role_was == "owner"
    return unless role_changed? || ngo_id_changed?
    return unless other_owners.none?

    errors.add(:base, :last_owner)
  end
end
