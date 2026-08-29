# frozen_string_literal: true

module Visibility
  # Quanto um leitor alcança, já resolvido. Não é o usuário: é a autorização
  # traduzida em nível, para que `visible_to` não precise conhecer papel,
  # política nem sessão — e para que o contexto anônimo seja representável.
  Context = Data.define(:clearance) do
    def self.anonymous
      new(clearance: :public)
    end

    def allowed_levels
      ceiling = Sensitive::LEVELS.fetch(clearance)

      Sensitive::LEVELS.select { |_level, rank| rank <= ceiling }.keys
    end

    # Registro confidential não guarda coordenada nenhuma; para os demais, ver
    # o ponto exato exige alcançar o nível do próprio registro.
    def can_see_precise_location?(record)
      allowed_levels.include?(record.sensitivity_level.to_sym)
    end
  end
end
