# frozen_string_literal: true

class CreateCountriesAndRegions < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      # O nome do país NÃO é coluna: sai do locale, por `countries.<iso_code>`.
      # Traduzir vira adicionar arquivo em vez de migrar dado, e some a
      # divergência entre "Coreia do Norte" e "Coréia do Norte" gravadas em
      # linhas diferentes.
      t.string :iso_code, null: false, limit: 2
      t.string :iso3_code, null: false, limit: 3

      # O nível com que uma obra criada neste país nasce. Default igual ao do
      # concern `Sensitive`, e vindo dele: duas listas de níveis divergindo é
      # questão de tempo.
      t.integer :default_sensitivity, null: false,
                                      default: Sensitive::LEVELS.fetch(Sensitive::DEFAULT_LEVEL)

      # Decisão editorial da equipe, carregada de db/vocabulary/countries.yml.
      # É ela que empurra `default_sensitivity` para `confidential`.
      t.boolean :high_risk, null: false, default: false

      t.string :currency_code, limit: 3

      t.timestamps

      t.index :iso_code, unique: true
      t.index :iso3_code, unique: true
    end

    create_table :regions do |t|
      # `index: false` porque o índice único abaixo já começa por `country_id`
      # — um índice só em `country_id` seria prefixo dele, e redundante.
      t.references :country, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :code

      t.timestamps

      t.index %i[country_id name], unique: true
    end
  end
end
