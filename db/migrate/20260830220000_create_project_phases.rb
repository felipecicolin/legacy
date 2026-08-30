# frozen_string_literal: true

class CreateProjectPhases < ActiveRecord::Migration[8.1]
  def change
    create_table :project_phases do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.integer :weight, null: false, default: 0
      t.integer :physical_progress, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :project_phases, %i[project_id position]
    add_foreign_key :budget_lines, :project_phases, on_delete: :nullify
    add_check_constraint :project_phases, "weight >= 0", name: "project_phases_weight_not_negative"
    add_check_constraint :project_phases, "physical_progress between 0 and 100",
                         name: "project_phases_progress_within_range"
    add_check_constraint :project_phases, "position >= 0", name: "project_phases_position_not_negative"
  end
end
