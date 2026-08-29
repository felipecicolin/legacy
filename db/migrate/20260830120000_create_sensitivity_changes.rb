# frozen_string_literal: true

class CreateSensitivityChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :sensitivity_changes do |t|
      # Polimórfico porque toda obra em campo — e o que vier depois dela — usa
      # o mesmo concern, e um log por tabela viraria N logs para auditar.
      t.references :record, polymorphic: true, null: false, index: true
      t.references :author, null: false, foreign_key: { to_table: :users }, index: true
      t.integer :from_level, null: false
      t.integer :to_level, null: false
      t.text :justification, null: false

      t.timestamps
    end
  end
end
