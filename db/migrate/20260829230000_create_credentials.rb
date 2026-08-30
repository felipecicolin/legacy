# frozen_string_literal: true

class CreateCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :credentials do |t|
      t.references :profile, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :number, null: false
      t.string :issuing_body, null: false
      # O vínculo com Country entra junto com a tabela de países em #25.
      t.date :issued_on
      t.date :expires_on
      t.integer :verification_status, null: false, default: 0
      t.timestamps
    end

    add_index :credentials, [:profile_id, :kind]
    add_index :credentials, [:verification_status, :expires_on]
  end
end
