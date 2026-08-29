# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    # `index: false` nas duas referências porque os índices compostos abaixo já
    # começam por elas: um índice de coluna só seria prefixo redundante, e o
    # `database_consistency` cobra tanto a FK indexada quanto a redundância.
    create_table :memberships do |t|
      t.references :profile, null: false, foreign_key: true, index: false
      t.references :organization, null: false, foreign_key: true, index: false
      t.integer :role, null: false
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :memberships, %i[profile_id organization_id], unique: true
    add_index :memberships, %i[organization_id role]
  end
end
