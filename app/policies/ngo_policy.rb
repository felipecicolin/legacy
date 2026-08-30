# frozen_string_literal: true

# A fusão junta duas perguntas que antes moravam em policies separadas: quanto
# deste mundo o leitor enxerga (era da base, e sai da sensibilidade) e se este
# cadastro específico já é vitrine (era da organização, e sai do estado mais do
# vínculo). Ver docs/ngos.md.
class NgoPolicy < ApplicationPolicy
  # Só a sensibilidade filtra aqui. O estado fica no `show?` de propósito: quem
  # tem vínculo precisa alcançar a PRÓPRIA ONG ainda pendente, e um escopo que
  # já tivesse descartado a linha não deixaria o `show?` decidir nada.
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.visible_to(context.visibility)
  end

  # Quem responde pela ONG. `representative` e `member` não entram: representar
  # uma instituição numa parceria não é administrar o cadastro dela.
  MANAGING_ROLES = %i[owner admin].freeze

  def index? = true

  # ONG ativa é vitrine — quem financia precisa poder olhar antes de ter conta.
  # `pending`, `suspended` e `inactive` só aparecem para quem tem vínculo e para
  # a equipe: a fila de aprovação não é informação pública, e uma suspensão
  # exposta é acusação sem contraditório.
  def show?
    visible_record? && (record.ngo_status_active? || member? || context.staff?)
  end

  def create? = context.signed_in?

  def update? = manages? || context.platform_admin?

  # Só quem é dono, e não quem administra: `admin` de ONG é papel operacional, e
  # apagar a ONG apaga o vínculo de todo mundo nela.
  def destroy? = owner? || context.platform_admin?

  def approve? = staff_at_least?(:curator)

  private

  # Não vai ao banco: o contexto já carregou os vínculos aceitos.
  def role = context.role_in(record)

  def member? = role.present?

  def manages? = MANAGING_ROLES.include?(role)

  def owner? = role == :owner
end
