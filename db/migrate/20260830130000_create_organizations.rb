# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      # `organization_kind` e `organization_status`, e não `kind`/`status`: o
      # rótulo de enum é a chave `<enum no plural>.<valor>` num vocabulário
      # compartilhado, e `kinds`/`statuses` já são de `PaymentTransaction`.
      # Ver docs/organizations.md.
      t.integer :organization_kind, null: false
      t.integer :organization_status, null: false, default: 0
      t.string :legal_document
      t.string :website

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, %i[organization_kind organization_status]
  end
end
