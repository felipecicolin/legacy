# frozen_string_literal: true

class CredentialPolicy < ApplicationPolicy
  # Quem verifica registro profissional. `support` fica de fora de propósito:
  # o documento é CPF, RG e número de conselho de uma pessoa real, e atender
  # chamado não exige lê-lo.
  VERIFYING_LEVELS = %i[curator admin].freeze

  # O documento é do dono e de quem verifica — ninguém mais, nem outro membro
  # da mesma organização.
  def show? = own? || verifier?

  private

  def own? = record.profile_id == context.profile&.id

  def verifier? = VERIFYING_LEVELS.include?(context.staff_level)
end
