# frozen_string_literal: true

# Log de auditoria da exposição: quem afrouxou a restrição de qual registro,
# quando e por quê. Só o `Sensitive#promote_visibility!` escreve aqui, e é a
# existência desta linha que separa uma decisão de um `update` esquecido.
class SensitivityChange < ApplicationRecord
  # Levantada quando alguém tenta editar uma linha de auditoria já gravada.
  class Immutable < StandardError; end

  belongs_to :record, polymorphic: true
  belongs_to :author, class_name: "User", inverse_of: :authored_sensitivity_changes

  # `prefix` porque os dois enums têm os mesmos valores: sem ele o segundo
  # sobrescreveria os predicados do primeiro.
  enum :from_level, Sensitive::LEVELS, prefix: true, validate: true
  enum :to_level, Sensitive::LEVELS, prefix: true, validate: true

  validates :justification, presence: true

  # A linha responde "quem abriu esta obra, e com base em quê". Reescrevê-la
  # depois não deixa lacuna: deixa uma resposta errada com cara de legítima, que
  # é pior do que resposta nenhuma. Levanta em vez de devolver `false` porque
  # gravação de auditoria que falha calada é o mesmo que auditoria nenhuma.
  # `update_all` continua fora do alcance — ver docs/visibility.md.
  before_update :refuse_rewrite

  private

  def refuse_rewrite
    raise Immutable, "sensitivity_change ##{id}"
  end
end
