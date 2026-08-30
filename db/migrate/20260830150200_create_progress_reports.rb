# frozen_string_literal: true

class CreateProgressReports < ActiveRecord::Migration[8.1]
  def change
    create_table :progress_reports do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :reported_by, null: false, foreign_key: { to_table: :profiles }
      t.date :reported_on, null: false
      t.integer :physical_progress, null: false
      t.integer :workers_on_site
      t.integer :status, null: false, default: 0
      t.references :approved_by, foreign_key: { to_table: :profiles }
      t.datetime :approved_at

      t.timestamps
    end

    # O primeiro serve à listagem por data; o segundo é o desempate do
    # `latest_per_project`, que ordena por `reported_on desc, id desc`.
    add_index :progress_reports, %i[project_id reported_on]
    add_index :progress_reports, %i[project_id created_at]

    # Faixa cobrada no banco, e não só na validação: um percentual fora de
    # faixa que entre por seed ou por console corrompe o cache da obra, e o
    # cache é o que ordena as listagens. Ver docs/field.md.
    add_check_constraint :progress_reports, "physical_progress between 0 and 100",
                         name: "progress_reports_physical_progress_within_range"
    add_check_constraint :progress_reports, "workers_on_site is null or workers_on_site >= 0",
                         name: "progress_reports_workers_not_negative"
  end
end
