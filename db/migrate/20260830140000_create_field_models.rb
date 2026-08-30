# frozen_string_literal: true

class CreateFieldModels < ActiveRecord::Migration[8.1]
  def change
    create_table :mission_bases do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :kind, null: false
      t.references :country, null: false, foreign_key: true, index: false
      t.references :region, foreign_key: true
      t.references :organization, foreign_key: true
      t.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.integer :status, null: false, default: 0
      t.date :established_on
      t.integer :people_served
      t.timestamps

      t.index :slug, unique: true
      t.index %i[country_id status]
      t.index :sensitivity_level
      t.check_constraint "sensitivity_level <> 2 or (nullif(btrim(latitude::text), '') is null " \
                        "and nullif(btrim(longitude::text), '') is null)",
                        name: "mission_bases_confidential_has_no_location"
    end

    create_table :projects do |t|
      t.string :code, null: false
      t.string :title, null: false
      t.references :mission_base, null: false, foreign_key: true, index: false
      t.integer :status, null: false, default: 0
      t.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)
      t.date :planned_start_on
      t.date :planned_end_on
      t.date :actual_start_on
      t.date :actual_end_on
      t.bigint :funding_target_cents, null: false, default: 0
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :physical_progress, null: false, default: 0
      t.timestamps

      t.index :code, unique: true
      t.index %i[mission_base_id status]
      t.index %i[status sensitivity_level]
      t.check_constraint "physical_progress between 0 and 100",
                        name: "projects_physical_progress_in_range"
      t.check_constraint "funding_target_cents >= 0",
                        name: "projects_funding_target_nonnegative"
    end
    create_table :site_surveys do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :surveyed_by, null: false, foreign_key: { to_table: :profiles }
      t.date :surveyed_on, null: false
      t.bigint :estimated_cost_cents
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :status, null: false, default: 0
      t.timestamps

      t.index %i[project_id surveyed_on]
      t.check_constraint "estimated_cost_cents is null or estimated_cost_cents >= 0",
                        name: "site_surveys_estimated_cost_nonnegative"
    end

    create_table :progress_reports do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :reported_by, null: false, foreign_key: { to_table: :profiles }
      t.date :reported_on, null: false
      t.integer :physical_progress, null: false
      t.integer :workers_on_site
      t.integer :status, null: false, default: 0
      t.references :approved_by, foreign_key: { to_table: :profiles, on_delete: :nullify }
      t.datetime :approved_at
      t.timestamps

      t.index %i[project_id reported_on]
      t.index %i[project_id created_at]
      t.check_constraint "physical_progress between 0 and 100",
                        name: "progress_reports_physical_progress_in_range"
    end

    create_table :project_participations do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :profile, null: false, foreign_key: true, index: false
      t.integer :role, null: false
      t.date :started_on, null: false
      t.date :ended_on
      t.integer :status, null: false, default: 0
      t.timestamps

      t.index %i[project_id profile_id role], unique: true
      t.index %i[profile_id status]
      t.check_constraint "ended_on is null or ended_on >= started_on",
                        name: "project_participations_dates_are_ordered"
    end

    create_table :project_photos do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :progress_report, foreign_key: { on_delete: :nullify }
      t.references :taken_by, foreign_key: { to_table: :profiles, on_delete: :nullify }
      t.date :taken_on, null: false
      t.string :caption
      t.integer :category, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps

      t.index %i[project_id category position]
      t.check_constraint "position >= 0", name: "project_photos_position_nonnegative"
    end
  end
end
