# frozen_string_literal: true

class CreateStaffRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_roles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :staff_level, null: false

      t.timestamps
    end
  end
end
