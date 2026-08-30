# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_30_150200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "countries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3
    t.integer "default_sensitivity", default: 1, null: false
    t.boolean "high_risk", default: false, null: false
    t.string "iso3_code", limit: 3, null: false
    t.string "iso_code", limit: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["iso3_code"], name: "index_countries_on_iso3_code", unique: true
    t.index ["iso_code"], name: "index_countries_on_iso_code", unique: true
  end

  create_table "credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expires_on"
    t.date "issued_on"
    t.string "issuing_body", null: false
    t.integer "kind", null: false
    t.string "number", null: false
    t.bigint "profile_id", null: false
    t.datetime "updated_at", null: false
    t.integer "verification_status", default: 0, null: false
    t.index ["profile_id", "kind"], name: "index_credentials_on_profile_id_and_kind"
    t.index ["verification_status", "expires_on"], name: "index_credentials_on_verification_status_and_expires_on"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.bigint "profile_id", null: false
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "role"], name: "index_memberships_on_organization_id_and_role"
    t.index ["profile_id", "organization_id"], name: "index_memberships_on_profile_id_and_organization_id", unique: true
  end

  create_table "mission_bases", force: :cascade do |t|
    t.string "address"
    t.integer "base_kind", null: false
    t.integer "base_status", default: 0, null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.date "established_on"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "name", null: false
    t.bigint "organization_id"
    t.integer "people_served"
    t.bigint "region_id"
    t.integer "sensitivity_level", default: 1, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id", "base_status"], name: "index_mission_bases_on_country_id_and_base_status"
    t.index ["organization_id"], name: "index_mission_bases_on_organization_id"
    t.index ["region_id"], name: "index_mission_bases_on_region_id"
    t.index ["sensitivity_level"], name: "index_mission_bases_on_sensitivity_level"
    t.index ["slug"], name: "index_mission_bases_on_slug", unique: true
    t.check_constraint "people_served IS NULL OR people_served >= 0", name: "mission_bases_people_served_not_negative"
    t.check_constraint "sensitivity_level <> 2 OR NULLIF(btrim(address::text), ''::text) IS NULL AND NULLIF(btrim(latitude::text), ''::text) IS NULL AND NULLIF(btrim(longitude::text), ''::text) IS NULL", name: "mission_bases_confidential_has_no_location"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "legal_document"
    t.string "name", null: false
    t.integer "organization_kind", null: false
    t.integer "organization_status", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["organization_kind", "organization_status"], name: "idx_on_organization_kind_organization_status_29282c9012"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "payment_transactions", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL", null: false
    t.string "failure_reason"
    t.string "kind", null: false
    t.datetime "processed_at"
    t.string "provider_reference", null: false
    t.string "reference", null: false
    t.boolean "simulated", default: true, null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["reference"], name: "index_payment_transactions_on_reference"
  end

  create_table "profile_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "proficiency", null: false
    t.bigint "profile_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "updated_at", null: false
    t.integer "years_of_experience"
    t.index ["profile_id", "skill_id"], name: "index_profile_skills_on_profile_id_and_skill_id", unique: true
    t.index ["skill_id"], name: "index_profile_skills_on_skill_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "headline"
    t.string "legal_name", null: false
    t.string "phone"
    t.string "preferred_locale", default: "pt-BR", null: false
    t.string "timezone", default: "America/Sao_Paulo", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
  end

  create_table "progress_reports", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.integer "physical_progress", null: false
    t.bigint "project_id", null: false
    t.bigint "reported_by_id", null: false
    t.date "reported_on", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "workers_on_site"
    t.index ["approved_by_id"], name: "index_progress_reports_on_approved_by_id"
    t.index ["project_id", "created_at"], name: "index_progress_reports_on_project_id_and_created_at"
    t.index ["project_id", "reported_on"], name: "index_progress_reports_on_project_id_and_reported_on"
    t.index ["reported_by_id"], name: "index_progress_reports_on_reported_by_id"
    t.check_constraint "physical_progress >= 0 AND physical_progress <= 100", name: "progress_reports_physical_progress_within_range"
    t.check_constraint "workers_on_site IS NULL OR workers_on_site >= 0", name: "progress_reports_workers_not_negative"
  end

  create_table "projects", force: :cascade do |t|
    t.date "actual_end_on"
    t.date "actual_start_on"
    t.virtual "code", type: :string, as: "('OB-'::text || lpad((code_number)::text, 4, '0'::text))", stored: true
    t.serial "code_number", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.bigint "funding_target_cents", default: 0, null: false
    t.bigint "mission_base_id", null: false
    t.integer "physical_progress", default: 0, null: false
    t.date "planned_end_on"
    t.date "planned_start_on"
    t.integer "sensitivity_level", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_projects_on_code", unique: true
    t.index ["mission_base_id", "status"], name: "index_projects_on_mission_base_id_and_status"
    t.index ["status", "sensitivity_level"], name: "index_projects_on_status_and_sensitivity_level"
    t.check_constraint "funding_target_cents >= 0", name: "projects_funding_target_not_negative"
    t.check_constraint "physical_progress >= 0 AND physical_progress <= 100", name: "projects_physical_progress_within_range"
  end

  create_table "regions", force: :cascade do |t|
    t.string "code"
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id", "name"], name: "index_regions_on_country_id_and_name", unique: true
  end

  create_table "sensitivity_changes", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.integer "from_level", null: false
    t.text "justification", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.integer "to_level", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_sensitivity_changes_on_author_id"
    t.index ["record_type", "record_id"], name: "index_sensitivity_changes_on_record"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "skills", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["category", "position"], name: "index_skills_on_category_and_position"
    t.index ["key"], name: "index_skills_on_key", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "staff_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "staff_level", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_staff_roles_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "credentials", "profiles"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "profiles"
  add_foreign_key "mission_bases", "countries"
  add_foreign_key "mission_bases", "organizations", on_delete: :nullify
  add_foreign_key "mission_bases", "regions"
  add_foreign_key "profile_skills", "profiles"
  add_foreign_key "profile_skills", "skills"
  add_foreign_key "profiles", "users"
  add_foreign_key "progress_reports", "profiles", column: "approved_by_id"
  add_foreign_key "progress_reports", "profiles", column: "reported_by_id"
  add_foreign_key "progress_reports", "projects"
  add_foreign_key "projects", "mission_bases"
  add_foreign_key "regions", "countries"
  add_foreign_key "sensitivity_changes", "users", column: "author_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "staff_roles", "users"
end
