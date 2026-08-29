# frozen_string_literal: true

class Credential < ApplicationRecord
  enum :kind, {
    crea: 0,
    cau: 1,
    other_professional: 2,
    license: 3,
    certificate: 4,
  }, validate: true

  enum :verification_status, {
    pending: 0,
    verified: 1,
    rejected: 2,
    expired: 3,
  }, default: :pending, validate: true

  belongs_to :profile
  has_one_attached :document, dependent: :purge

  validates :kind, :number, :issuing_body, :verification_status, presence: true

  # A data de expiração é avaliada no momento da candidatura. Não há job
  # diário: uma credencial verificada vencida deixa de passar pelo gate na
  # primeira leitura depois do vencimento.
  def valid_for_professional_registration?
    verified? && (expires_on&.future? == true)
  end
end
