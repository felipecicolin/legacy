# frozen_string_literal: true

# Log de auditoria da exposição: quem afrouxou a restrição de qual registro,
# quando e por quê. Só o `Sensitive#promote_visibility!` escreve aqui, e é a
# existência desta linha que separa uma decisão de um `update` esquecido.
class SensitivityChange < ApplicationRecord
  belongs_to :record, polymorphic: true
  belongs_to :author, class_name: "User", inverse_of: :authored_sensitivity_changes

  # `prefix` porque os dois enums têm os mesmos valores: sem ele o segundo
  # sobrescreveria os predicados do primeiro.
  enum :from_level, Sensitive::LEVELS, prefix: true, validate: true
  enum :to_level, Sensitive::LEVELS, prefix: true, validate: true

  validates :justification, presence: true
end
