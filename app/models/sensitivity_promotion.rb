# frozen_string_literal: true

# Autor e motivo de uma exposição. Existe como valor, e não como par de
# argumentos, porque `promote_visibility!` precisa carregar os dois até o
# `after_save` — e um deles sem o outro não autoriza nada.
SensitivityPromotion = Data.define(:author, :justification) do
  def justified?
    author.present? && justification.present?
  end
end
