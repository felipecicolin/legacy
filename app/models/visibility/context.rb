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

    # Duas perguntas diferentes com a mesma resposta hoje, e dois nomes de
    # propósito: o dia em que uma delas mudar de regra — identificar gente pode
    # pedir mais que ver a obra — o call site já está escrito na pergunta certa,
    # e não num predicado genérico que atenderia às duas por acidente.

    # Registro confidential não guarda coordenada nenhuma; para os demais, ver
    # o ponto exato exige alcançar o nível do próprio registro.
    def can_see_precise_location?(record) = reaches?(record)

    # Se a pessoa ao lado deste recurso aparece pelo nome público ou só pelo
    # papel. Quem decide é o recurso, não o perfil: `Profile` não tem nível de
    # sensibilidade, e o risco de nomear alguém vem da obra a que ela está
    # ligada. Ver `ProfilePresenter`.
    def can_identify?(record) = reaches?(record)

    private

    def reaches?(record)
      allowed_levels.include?(record.sensitivity_level.to_sym)
    end
  end
end
