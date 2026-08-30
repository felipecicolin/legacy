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

ActiveRecord::Schema[8.1].define(version: 2026_08_30_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "unaccent"

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

  create_table "assignments", force: :cascade do |t|
    t.integer "assignment_status", default: 0, null: false
    t.bigint "candidacy_id", null: false
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.bigint "need_id", null: false
    t.integer "quantity", default: 1, null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["candidacy_id"], name: "index_assignments_on_candidacy_id", unique: true
    t.index ["need_id", "assignment_status"], name: "index_assignments_on_need_id_and_assignment_status"
    t.check_constraint "ends_on IS NULL OR ends_on >= starts_on", name: "assignments_ends_after_it_starts"
    t.check_constraint "quantity > 0", name: "assignments_quantity_is_positive"
  end

  create_table "budget_lines", force: :cascade do |t|
    t.bigint "budget_id", null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "estimated_cents", null: false
    t.integer "position", default: 0, null: false
    t.bigint "project_phase_id"
    t.datetime "updated_at", null: false
    t.index ["budget_id", "position"], name: "index_budget_lines_on_budget_id_and_position"
    t.index ["project_phase_id"], name: "index_budget_lines_on_project_phase_id"
    t.check_constraint "estimated_cents >= 0", name: "budget_lines_estimated_not_negative"
  end

  create_table "budgets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.bigint "project_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["project_id", "version"], name: "index_budgets_on_project_id_and_version", unique: true
    t.check_constraint "total_cents >= 0", name: "budgets_total_not_negative"
    t.check_constraint "version > 0", name: "budgets_version_positive"
  end

  create_table "campaigns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.date "ends_on"
    t.bigint "goal_cents", null: false
    t.bigint "ngo_id", null: false
    t.bigint "project_id"
    t.bigint "raised_cents", default: 0, null: false
    t.integer "sensitivity_level", default: 1, null: false
    t.string "slug", null: false
    t.date "starts_on", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["ngo_id", "status"], name: "index_campaigns_on_ngo_id_and_status"
    t.index ["project_id", "status"], name: "index_campaigns_on_project_id_and_status"
    t.index ["slug"], name: "index_campaigns_on_slug", unique: true
    t.check_constraint "goal_cents > 0", name: "campaigns_goal_positive"
    t.check_constraint "raised_cents >= 0", name: "campaigns_raised_not_negative"
    t.check_constraint "sensitivity_level >= 0 AND sensitivity_level <= 2", name: "campaigns_sensitivity_level_valid"
  end

  create_table "candidacies", force: :cascade do |t|
    t.integer "candidacy_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.bigint "decided_by_id"
    t.bigint "need_id", null: false
    t.bigint "profile_id"
    t.integer "rejection_reason"
    t.datetime "updated_at", null: false
    t.bigint "volunteer_group_id"
    t.index ["decided_by_id"], name: "index_candidacies_on_decided_by_id"
    t.index ["need_id", "candidacy_status"], name: "index_candidacies_on_need_id_and_candidacy_status"
    t.index ["profile_id", "need_id"], name: "index_candidacies_on_profile_id_and_need_id", unique: true, where: "(profile_id IS NOT NULL)"
    t.index ["volunteer_group_id", "need_id"], name: "index_candidacies_on_volunteer_group_id_and_need_id", unique: true, where: "(volunteer_group_id IS NOT NULL)"
    t.check_constraint "(profile_id IS NULL) <> (volunteer_group_id IS NULL)", name: "candidacies_have_exactly_one_candidate"
  end

  create_table "contributions", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.boolean "anonymous", default: false, null: false
    t.bigint "campaign_id"
    t.datetime "confirmed_at"
    t.bigint "contributor_id"
    t.string "contributor_type"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.string "idempotency_key"
    t.integer "origin", default: 0, null: false
    t.string "provider_reference"
    t.boolean "simulated", default: true, null: false
    t.integer "status", default: 0, null: false
    t.bigint "subscription_id"
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "status"], name: "index_contributions_on_campaign_id_and_status"
    t.index ["contributor_type", "contributor_id"], name: "index_contributions_on_contributor_type_and_contributor_id"
    t.index ["idempotency_key"], name: "index_contributions_on_idempotency_key", unique: true
    t.index ["provider_reference"], name: "index_contributions_on_provider_reference", unique: true
    t.index ["subscription_id"], name: "index_contributions_on_subscription_id"
    t.check_constraint "amount_cents > 0", name: "contributions_amount_positive"
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

  create_table "deployment_members", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "deployment_id", null: false
    t.integer "member_role", null: false
    t.integer "member_status", default: 0, null: false
    t.bigint "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deployment_id", "profile_id"], name: "index_deployment_members_on_deployment_id_and_profile_id", unique: true
    t.index ["profile_id"], name: "index_deployment_members_on_profile_id"
  end

  create_table "deployments", force: :cascade do |t|
    t.integer "capacity"
    t.bigint "cost_per_person_cents"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.date "departs_on", null: false
    t.integer "deployment_status", default: 0, null: false
    t.string "name", null: false
    t.bigint "ngo_id", null: false
    t.bigint "project_id"
    t.date "returns_on", null: false
    t.datetime "updated_at", null: false
    t.index ["ngo_id", "deployment_status"], name: "index_deployments_on_ngo_id_and_deployment_status"
    t.index ["project_id"], name: "index_deployments_on_project_id"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "deployments_capacity_is_positive"
    t.check_constraint "cost_per_person_cents IS NULL OR cost_per_person_cents >= 0", name: "deployments_cost_not_negative"
    t.check_constraint "returns_on >= departs_on", name: "deployments_returns_after_it_departs"
  end

  create_table "event_registrations", force: :cascade do |t|
    t.bigint "contribution_id"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "profile_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["contribution_id"], name: "index_event_registrations_on_contribution_id", unique: true
    t.index ["event_id", "profile_id"], name: "index_event_registrations_on_event_id_and_profile_id", unique: true
    t.index ["profile_id"], name: "index_event_registrations_on_profile_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "campaign_id"
    t.integer "capacity"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.datetime "ends_at"
    t.integer "kind", null: false
    t.string "location_name"
    t.boolean "online", default: false, null: false
    t.integer "sensitivity_level", default: 1, null: false
    t.string "slug", null: false
    t.datetime "starts_at", null: false
    t.integer "status", default: 0, null: false
    t.bigint "ticket_price_cents", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_events_on_campaign_id"
    t.index ["country_id"], name: "index_events_on_country_id"
    t.index ["slug"], name: "index_events_on_slug", unique: true
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "events_capacity_positive"
    t.check_constraint "sensitivity_level >= 0 AND sensitivity_level <= 2", name: "events_sensitivity_level_valid"
    t.check_constraint "ticket_price_cents >= 0", name: "events_ticket_price_not_negative"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "budget_line_id"
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.date "incurred_on", null: false
    t.bigint "project_id", null: false
    t.bigint "recorded_by_id", null: false
    t.integer "sensitivity_level", default: 1, null: false
    t.boolean "simulated", default: true, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["budget_line_id"], name: "index_expenses_on_budget_line_id"
    t.index ["project_id", "incurred_on"], name: "index_expenses_on_project_id_and_incurred_on"
    t.index ["recorded_by_id"], name: "index_expenses_on_recorded_by_id"
    t.check_constraint "amount_cents > 0", name: "expenses_amount_positive"
    t.check_constraint "sensitivity_level >= 0 AND sensitivity_level <= 2", name: "expenses_sensitivity_level_valid"
  end

  create_table "in_kind_donations", force: :cascade do |t|
    t.bigint "campaign_id"
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.string "decline_reason"
    t.date "delivered_on"
    t.bigint "donor_id", null: false
    t.string "donor_type", null: false
    t.bigint "estimated_value_cents"
    t.date "expected_on"
    t.bigint "need_id"
    t.integer "quantity", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_in_kind_donations_on_campaign_id"
    t.index ["donor_type", "donor_id", "status"], name: "index_in_kind_donations_on_donor_type_and_donor_id_and_status"
    t.index ["need_id", "status"], name: "index_in_kind_donations_on_need_id_and_status"
    t.check_constraint "estimated_value_cents IS NULL OR estimated_value_cents >= 0", name: "in_kind_donations_value_not_negative"
    t.check_constraint "quantity > 0", name: "in_kind_donations_quantity_positive"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.bigint "ngo_id", null: false
    t.bigint "profile_id", null: false
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.index ["ngo_id", "role"], name: "index_memberships_on_ngo_id_and_role"
    t.index ["profile_id", "ngo_id"], name: "index_memberships_on_profile_id_and_ngo_id", unique: true
  end

  create_table "need_fulfillments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "fulfilled_at", null: false
    t.bigint "need_id", null: false
    t.integer "quantity", null: false
    t.bigint "source_id", null: false
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["need_id", "source_type", "source_id"], name: "idx_on_need_id_source_type_source_id_53b8be6096", unique: true
    t.index ["source_type", "source_id"], name: "index_need_fulfillments_on_source_type_and_source_id"
    t.check_constraint "quantity > 0", name: "need_fulfillments_quantity_is_positive"
  end

  create_table "needs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.bigint "estimated_value_cents"
    t.integer "fulfilled_quantity", default: 0, null: false
    t.integer "need_kind", null: false
    t.integer "need_status", default: 0, null: false
    t.date "needed_by"
    t.bigint "ngo_id", null: false
    t.bigint "project_id"
    t.integer "quantity", default: 1, null: false
    t.boolean "requires_professional_registration", default: false, null: false
    t.integer "sensitivity_level", default: 1, null: false
    t.bigint "skill_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "urgency", default: 1, null: false
    t.index ["need_kind", "need_status", "urgency"], name: "index_needs_on_need_kind_and_need_status_and_urgency"
    t.index ["ngo_id", "need_status"], name: "index_needs_on_ngo_id_and_need_status"
    t.index ["project_id", "need_status"], name: "index_needs_on_project_id_and_need_status"
    t.index ["skill_id"], name: "index_needs_on_skill_id"
    t.check_constraint "estimated_value_cents IS NULL OR estimated_value_cents >= 0", name: "needs_estimated_value_not_negative"
    t.check_constraint "fulfilled_quantity >= 0 AND fulfilled_quantity <= quantity", name: "needs_fulfilled_within_quantity"
    t.check_constraint "quantity > 0", name: "needs_quantity_is_positive"
  end

  create_table "ngos", force: :cascade do |t|
    t.string "address"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.date "established_on"
    t.decimal "latitude", precision: 9, scale: 6
    t.string "legal_document"
    t.decimal "longitude", precision: 9, scale: 6
    t.string "name", null: false
    t.integer "ngo_kind", null: false
    t.integer "ngo_status", default: 0, null: false
    t.integer "people_served"
    t.bigint "region_id"
    t.integer "sensitivity_level", default: 1, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["country_id", "ngo_status"], name: "index_ngos_on_country_id_and_ngo_status"
    t.index ["ngo_kind", "ngo_status"], name: "index_ngos_on_ngo_kind_and_ngo_status"
    t.index ["region_id"], name: "index_ngos_on_region_id"
    t.index ["sensitivity_level"], name: "index_ngos_on_sensitivity_level"
    t.index ["slug"], name: "index_ngos_on_slug", unique: true
    t.check_constraint "people_served IS NULL OR people_served >= 0", name: "ngos_people_served_not_negative"
    t.check_constraint "sensitivity_level <> 2 OR NULLIF(btrim(address::text), ''::text) IS NULL AND NULLIF(btrim(latitude::text), ''::text) IS NULL AND NULLIF(btrim(longitude::text), ''::text) IS NULL", name: "ngos_confidential_has_no_location"
  end

  create_table "partnerships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.integer "kind", null: false
    t.bigint "ngo_id", null: false
    t.bigint "owner_id"
    t.integer "sensitivity_level", default: 1, null: false
    t.date "starts_on", null: false
    t.integer "status", default: 0, null: false
    t.integer "tier", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "tier", "status"], name: "index_partnerships_on_kind_and_tier_and_status"
    t.index ["ngo_id", "status"], name: "index_partnerships_on_ngo_id_and_status"
    t.index ["owner_id"], name: "index_partnerships_on_owner_id"
    t.check_constraint "sensitivity_level >= 0 AND sensitivity_level <= 2", name: "partnerships_sensitivity_level_valid"
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

  create_table "project_participations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ended_on"
    t.integer "participation_role", null: false
    t.integer "participation_status", default: 0, null: false
    t.bigint "profile_id", null: false
    t.bigint "project_id", null: false
    t.date "started_on", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "participation_status"], name: "idx_on_profile_id_participation_status_034dbcd2f9"
    t.index ["project_id", "profile_id", "participation_role"], name: "idx_on_project_id_profile_id_participation_role_364d007448", unique: true
    t.check_constraint "ended_on IS NULL OR ended_on >= started_on", name: "project_participations_ends_after_it_starts"
  end

  create_table "project_photos", force: :cascade do |t|
    t.string "caption"
    t.datetime "created_at", null: false
    t.integer "photo_category", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.bigint "progress_report_id"
    t.bigint "project_id", null: false
    t.bigint "taken_by_id"
    t.date "taken_on", null: false
    t.datetime "updated_at", null: false
    t.index ["progress_report_id"], name: "index_project_photos_on_progress_report_id"
    t.index ["project_id", "photo_category", "position"], name: "idx_on_project_id_photo_category_position_c69d933c2d"
    t.index ["taken_by_id"], name: "index_project_photos_on_taken_by_id"
    t.check_constraint "\"position\" >= 0", name: "project_photos_position_not_negative"
  end

  create_table "projects", force: :cascade do |t|
    t.date "actual_end_on"
    t.date "actual_start_on"
    t.virtual "code", type: :string, as: "('OB-'::text || lpad((code_number)::text, 4, '0'::text))", stored: true
    t.serial "code_number", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.bigint "funding_target_cents", default: 0, null: false
    t.bigint "ngo_id", null: false
    t.integer "physical_progress", default: 0, null: false
    t.date "planned_end_on"
    t.date "planned_start_on"
    t.integer "sensitivity_level", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_projects_on_code", unique: true
    t.index ["ngo_id", "status"], name: "index_projects_on_ngo_id_and_status"
    t.index ["status", "sensitivity_level"], name: "index_projects_on_status_and_sensitivity_level"
    t.check_constraint "funding_target_cents >= 0", name: "projects_funding_target_not_negative"
    t.check_constraint "physical_progress >= 0 AND physical_progress <= 100", name: "projects_physical_progress_within_range"
  end

  create_table "receipts", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "contribution_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.datetime "issued_at", null: false
    t.integer "issued_year", null: false
    t.string "number", null: false
    t.serial "sequence_number", null: false
    t.boolean "simulated", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["contribution_id"], name: "index_receipts_on_contribution_id", unique: true
    t.index ["number"], name: "index_receipts_on_number", unique: true
    t.check_constraint "amount_cents > 0", name: "receipts_amount_positive"
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

  create_table "site_surveys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.bigint "estimated_cost_cents"
    t.bigint "project_id", null: false
    t.integer "status", default: 0, null: false
    t.bigint "surveyed_by_id", null: false
    t.date "surveyed_on", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "surveyed_on"], name: "index_site_surveys_on_project_id_and_surveyed_on"
    t.index ["surveyed_by_id"], name: "index_site_surveys_on_surveyed_by_id"
    t.check_constraint "estimated_cost_cents IS NULL OR estimated_cost_cents >= 0", name: "site_surveys_estimated_cost_not_negative"
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

  create_table "subscriber_benefits", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.date "due_on", null: false
    t.integer "kind", null: false
    t.text "skipped_reason"
    t.integer "status", default: 0, null: false
    t.bigint "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "due_on"], name: "index_subscriber_benefits_on_status_and_due_on"
    t.index ["subscription_id", "kind", "due_on"], name: "index_benefits_on_subscription_kind_due", unique: true
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "BRL", null: false
    t.integer "interval", default: 0, null: false
    t.string "key", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_subscription_plans_on_key", unique: true
    t.check_constraint "amount_cents > 0", name: "subscription_plans_amount_positive"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "campaign_id"
    t.date "cancelled_on"
    t.datetime "created_at", null: false
    t.integer "cycles_completed", default: 0, null: false
    t.date "next_charge_on", null: false
    t.date "retry_on"
    t.boolean "simulated", default: true, null: false
    t.date "started_on", null: false
    t.integer "status", default: 0, null: false
    t.bigint "subscriber_id", null: false
    t.string "subscriber_type", null: false
    t.bigint "subscription_plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_subscriptions_on_campaign_id"
    t.index ["status", "next_charge_on"], name: "index_subscriptions_on_status_and_next_charge_on"
    t.index ["subscriber_type", "subscriber_id", "status"], name: "idx_on_subscriber_type_subscriber_id_status_83d89065ec"
    t.index ["subscription_plan_id"], name: "index_subscriptions_on_subscription_plan_id"
    t.check_constraint "cycles_completed >= 0", name: "subscriptions_cycles_not_negative"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "volunteer_engagements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ended_on"
    t.integer "engagement_area", null: false
    t.integer "engagement_model", null: false
    t.integer "engagement_status", default: 0, null: false
    t.bigint "ngo_id"
    t.bigint "profile_id", null: false
    t.date "started_on", null: false
    t.datetime "updated_at", null: false
    t.bigint "volunteer_group_id"
    t.integer "weekly_hours"
    t.index ["engagement_model", "engagement_area", "engagement_status"], name: "idx_on_engagement_model_engagement_area_engagement__c56218c508"
    t.index ["ngo_id"], name: "index_volunteer_engagements_on_ngo_id"
    t.index ["profile_id", "engagement_status"], name: "idx_on_profile_id_engagement_status_8c05c156e4"
    t.index ["volunteer_group_id"], name: "index_volunteer_engagements_on_volunteer_group_id"
    t.check_constraint "ended_on IS NULL OR ended_on >= started_on", name: "volunteer_engagements_end_after_it_starts"
    t.check_constraint "weekly_hours IS NULL OR weekly_hours >= 1 AND weekly_hours <= 168", name: "volunteer_engagements_weekly_hours_within_a_week"
  end

  create_table "volunteer_groups", force: :cascade do |t|
    t.date "available_from"
    t.date "available_until"
    t.bigint "coordinator_id", null: false
    t.datetime "created_at", null: false
    t.integer "expected_size"
    t.integer "group_status", default: 0, null: false
    t.string "name", null: false
    t.bigint "ngo_id", null: false
    t.datetime "updated_at", null: false
    t.index ["coordinator_id"], name: "index_volunteer_groups_on_coordinator_id"
    t.index ["ngo_id", "group_status"], name: "index_volunteer_groups_on_ngo_id_and_group_status"
    t.check_constraint "available_until IS NULL OR available_from IS NULL OR available_until >= available_from", name: "volunteer_groups_window_ends_after_it_starts"
    t.check_constraint "expected_size IS NULL OR expected_size > 0", name: "volunteer_groups_expected_size_is_positive"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assignments", "candidacies"
  add_foreign_key "assignments", "needs"
  add_foreign_key "budget_lines", "budgets"
  add_foreign_key "budgets", "projects"
  add_foreign_key "campaigns", "ngos"
  add_foreign_key "campaigns", "projects"
  add_foreign_key "candidacies", "needs"
  add_foreign_key "candidacies", "profiles"
  add_foreign_key "candidacies", "profiles", column: "decided_by_id"
  add_foreign_key "candidacies", "volunteer_groups"
  add_foreign_key "contributions", "campaigns"
  add_foreign_key "contributions", "subscriptions"
  add_foreign_key "credentials", "profiles"
  add_foreign_key "deployment_members", "deployments"
  add_foreign_key "deployment_members", "profiles"
  add_foreign_key "deployments", "ngos"
  add_foreign_key "deployments", "projects", on_delete: :nullify
  add_foreign_key "event_registrations", "contributions", on_delete: :nullify
  add_foreign_key "event_registrations", "events"
  add_foreign_key "event_registrations", "profiles"
  add_foreign_key "events", "campaigns", on_delete: :nullify
  add_foreign_key "events", "countries"
  add_foreign_key "expenses", "budget_lines", on_delete: :nullify
  add_foreign_key "expenses", "profiles", column: "recorded_by_id"
  add_foreign_key "expenses", "projects"
  add_foreign_key "in_kind_donations", "campaigns", on_delete: :nullify
  add_foreign_key "memberships", "ngos"
  add_foreign_key "memberships", "profiles"
  add_foreign_key "need_fulfillments", "needs"
  add_foreign_key "needs", "ngos"
  add_foreign_key "needs", "projects"
  add_foreign_key "needs", "skills"
  add_foreign_key "ngos", "countries"
  add_foreign_key "ngos", "regions"
  add_foreign_key "partnerships", "ngos"
  add_foreign_key "partnerships", "profiles", column: "owner_id", on_delete: :nullify
  add_foreign_key "profile_skills", "profiles"
  add_foreign_key "profile_skills", "skills"
  add_foreign_key "profiles", "users"
  add_foreign_key "progress_reports", "profiles", column: "approved_by_id"
  add_foreign_key "progress_reports", "profiles", column: "reported_by_id"
  add_foreign_key "progress_reports", "projects"
  add_foreign_key "project_participations", "profiles"
  add_foreign_key "project_participations", "projects"
  add_foreign_key "project_photos", "profiles", column: "taken_by_id", on_delete: :nullify
  add_foreign_key "project_photos", "progress_reports", on_delete: :nullify
  add_foreign_key "project_photos", "projects"
  add_foreign_key "projects", "ngos"
  add_foreign_key "receipts", "contributions"
  add_foreign_key "regions", "countries"
  add_foreign_key "sensitivity_changes", "users", column: "author_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "site_surveys", "profiles", column: "surveyed_by_id"
  add_foreign_key "site_surveys", "projects"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "staff_roles", "users"
  add_foreign_key "subscriber_benefits", "subscriptions"
  add_foreign_key "subscriptions", "campaigns", on_delete: :nullify
  add_foreign_key "subscriptions", "subscription_plans"
  add_foreign_key "volunteer_engagements", "ngos", on_delete: :nullify
  add_foreign_key "volunteer_engagements", "profiles"
  add_foreign_key "volunteer_engagements", "volunteer_groups"
  add_foreign_key "volunteer_groups", "ngos"
  add_foreign_key "volunteer_groups", "profiles", column: "coordinator_id"
end
