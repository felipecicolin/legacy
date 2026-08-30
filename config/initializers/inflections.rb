# frozen_string_literal: true

ActiveSupport::Inflector.inflections(:en) do |inflect|
  # O inflector do Rails singulariza "bases" como "basis" — a regra latina de
  # `basis`/`bases`. `MissionBase#pluralize` dá "mission_bases", mas o caminho
  # de volta dá "MissionBasis", e é ele que um `has_many :mission_bases` usa
  # para achar a classe: sem esta linha a associação aponta para um modelo que
  # não existe, e o erro só aparece na primeira leitura.
  #
  # A regra é registrada para a palavra composta, e não para "base": a
  # singularização latina segue valendo onde ela está certa.
  inflect.irregular("mission_base", "mission_bases")
end
