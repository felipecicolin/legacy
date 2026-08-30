# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.visible
  end

  def index? = true

  # Quem responde pela organização. `representative` e `member` não entram:
  # representar uma empresa numa parceria não é administrar o cadastro dela.
  MANAGING_ROLES = %i[owner admin].freeze

  # Organização aprovada é vitrine — quem financia precisa poder olhar antes de
  # ter conta. `pending` e `suspended` só aparecem para quem tem vínculo e para
  # a equipe: a fila de aprovação não é informação pública, e uma suspensão
  # exposta é acusação sem contraditório.
  def show?
    record.approved? || member? || context.staff?
  end

  def create? = context.signed_in?

  def update? = manages? || context.platform_admin?

  # Só quem é dono, e não quem administra: `admin` de organização é papel
  # operacional, e apagar a organização apaga o vínculo de todo mundo nela.
  def destroy? = owner? || context.platform_admin?

  def approve? = staff_at_least?(:curator)

  private

  # Não vai ao banco: o contexto já carregou os vínculos aceitos.
  def role = context.role_in(record)

  def member? = role.present?

  def manages? = MANAGING_ROLES.include?(role)

  def owner? = role == :owner
end
