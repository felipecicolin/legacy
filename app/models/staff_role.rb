# frozen_string_literal: true

# O papel de quem trabalha NA plataforma, e só dele. Papel de campo é contexto
# e mora do lado do contexto — `Membership#role` para organização,
# `ProjectParticipation#role` para obra. Ver docs/authorization.md.
#
# Tabela separada, e não coluna em `users`: a esmagadora maioria das contas não
# é da equipe, e uma coluna com default faria "é staff?" ser respondida por
# omissão. Com tabela, a ausência de linha é a resposta — e ela é explícita.
class StaffRole < ApplicationRecord
  # O nome do enum não é `level` porque o rótulo de UI sai de `<enum no
  # plural>.<valor>` (ver docs/i18n.md): um `levels:` solto no topo do locale
  # não diria de que escala se trata, ao lado de `sensitivity_levels` e
  # `from_levels`. Mesma razão de `Organization#organization_kind`.
  #
  # A ordem é crescente em alcance, e é ela que o `Authorization::Context` lê
  # para traduzir papel em nível de visibilidade.
  enum :staff_level, { support: 0, curator: 1, admin: 2 }, validate: true

  belongs_to :user

  # Quem garante um papel por pessoa é o índice único; a validação existe para
  # a segunda tentativa virar erro de formulário em vez de exceção de driver, e
  # é ela que o `database_consistency` cobra ao ver o índice único.
  validates :user_id, uniqueness: true
  validates :staff_level, presence: true

  def staff_level_label
    I18n.t(staff_level, scope: :staff_levels)
  end
end
