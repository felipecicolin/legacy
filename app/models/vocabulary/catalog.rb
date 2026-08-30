# frozen_string_literal: true

module Vocabulary
  # Leitor do vocabulário curado em `db/vocabulary/`.
  #
  # O YAML é a fonte, e o seed lê daqui em vez de redigitar a lista: duas
  # listas divergindo é questão de tempo, e a que ninguém abre é a que fica
  # errada. Ver docs/vocabulary.md.
  class Catalog
    DIRECTORY = "db/vocabulary"

    def self.countries
      new("countries")
    end

    def self.skills
      new("skills")
    end

    def initialize(name)
      @name = name
    end

    def path
      Rails.root.join(DIRECTORY, "#{@name}.yml")
    end

    # Sem memoização de propósito: o arquivo é lido uma vez pelo seed e uma vez
    # pelo spec de catálogo, e um `||=` seria um estado a invalidar sozinho
    # depois que alguém editar o YAML no console.
    #
    # `symbolize_keys` para o resultado servir direto a um `update!`.
    def entries
      YAML.safe_load_file(path).map(&:symbolize_keys)
    end
  end
end
