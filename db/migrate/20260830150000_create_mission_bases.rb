# frozen_string_literal: true

class CreateMissionBases < ActiveRecord::Migration[8.1]
  def change
    create_table :mission_bases do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :base_kind, null: false
      t.integer :base_status, null: false, default: 0
      t.references :country, null: false, foreign_key: true, index: false
      t.references :region, foreign_key: true
      # `on_delete: :nullify` no banco para casar com o `dependent: :nullify` do
      # modelo: sem ele, um DELETE que não passe pelo Active Record — script de
      # correção, SQL cru — reprovaria na FK em vez de soltar a base.
      t.references :organization, foreign_key: { on_delete: :nullify }
      t.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)
      t.string :address
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.date :established_on
      t.integer :people_served

      t.timestamps
    end

    add_index :mission_bases, :slug, unique: true
    add_index :mission_bases, %i[country_id base_status]
    add_index :mission_bases, :sensitivity_level

    # A receita que toda tabela com o concern `Sensitive` carrega: é a terceira
    # camada da regra de coordenada, e a única que alcança `update_column`,
    # `update_all` e `insert_all`. Ver docs/visibility.md.
    add_check_constraint :mission_bases, Sensitive::PRECISE_LOCATION_CHECK,
                         name: "mission_bases_confidential_has_no_location"

    # Percentual só existe onde ele é medido — não há CHECK aqui.
    add_check_constraint :mission_bases, "people_served is null or people_served >= 0",
                         name: "mission_bases_people_served_not_negative"
  end
end
