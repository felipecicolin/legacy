# frozen_string_literal: true

class CreateProjectParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :project_participations do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :profile, null: false, foreign_key: true, index: false
      t.integer :participation_role, null: false
      t.date :started_on, null: false
      t.date :ended_on
      t.integer :participation_status, null: false, default: 0

      t.timestamps
    end

    # O papel entra no índice único de propósito: a mesma pessoa pode ser
    # `technical_lead` E `local_host` na mesma obra, e deixá-lo de fora
    # proibiria um caso real.
    add_index :project_participations, %i[project_id profile_id participation_role], unique: true
    add_index :project_participations, %i[profile_id participation_status]

    add_check_constraint :project_participations, "ended_on is null or ended_on >= started_on",
                         name: "project_participations_ends_after_it_starts"
  end
end
