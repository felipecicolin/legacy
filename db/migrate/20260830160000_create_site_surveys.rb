# frozen_string_literal: true

class CreateSiteSurveys < ActiveRecord::Migration[8.1]
  def change
    create_table :site_surveys do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :surveyed_by, null: false, foreign_key: { to_table: :profiles }
      t.date :surveyed_on, null: false
      t.bigint :estimated_cost_cents
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :site_surveys, %i[project_id surveyed_on]

    add_check_constraint :site_surveys, "estimated_cost_cents is null or estimated_cost_cents >= 0",
                         name: "site_surveys_estimated_cost_not_negative"
  end
end
