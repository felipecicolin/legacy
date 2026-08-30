# frozen_string_literal: true

class CreateFundingDomain < ActiveRecord::Migration[8.1]
  def change
    create_campaigns
    create_subscriptions_and_benefits
    create_contributions_and_receipts
    create_budgets_and_expenses
    create_channels
  end

  private

  def create_campaigns
    create_table :campaigns do |t|
      t.references :mission_base, null: false, foreign_key: true, index: false
      t.references :project, foreign_key: true, index: false
      t.string :title, null: false
      t.string :slug, null: false
      t.bigint :goal_cents, null: false
      t.string :currency, null: false, default: "BRL", limit: 3
      t.bigint :raised_cents, null: false, default: 0
      t.date :starts_on, null: false
      t.date :ends_on
      t.integer :status, null: false, default: 0
      t.integer :sensitivity_level, null: false, default: 1
      t.timestamps
    end
    add_index :campaigns, :slug, unique: true
    add_index :campaigns, %i[mission_base_id status]
    add_index :campaigns, %i[project_id status]
    add_check_constraint :campaigns, "goal_cents > 0", name: "campaigns_goal_positive"
    add_check_constraint :campaigns, "raised_cents >= 0", name: "campaigns_raised_not_negative"
    add_check_constraint :campaigns, "sensitivity_level between 0 and 2",
                         name: "campaigns_sensitivity_level_valid"
  end

  def create_contributions_and_receipts
    create_table :contributions do |t|
      t.bigint :campaign_id, null: true
      t.references :contributor, polymorphic: true, index: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :status, null: false, default: 0
      t.integer :origin, null: false, default: 0
      t.references :subscription, foreign_key: true
      t.string :provider_reference
      t.string :idempotency_key
      t.boolean :simulated, null: false, default: true
      t.boolean :anonymous, null: false, default: false
      t.datetime :confirmed_at
      t.timestamps
    end
    add_index :contributions, %i[campaign_id status]
    add_foreign_key :contributions, :campaigns
    change_column_null :contributions, :campaign_id, true
    add_index :contributions, %i[contributor_type contributor_id]
    add_index :contributions, :provider_reference, unique: true
    add_index :contributions, :idempotency_key, unique: true
    add_check_constraint :contributions, "amount_cents > 0", name: "contributions_amount_positive"

    create_table :receipts do |t|
      t.references :contribution, null: false, foreign_key: true, index: false
      t.string :number, null: false
      t.integer :issued_year, null: false
      t.serial :sequence_number, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "BRL", limit: 3
      t.boolean :simulated, null: false, default: true
      t.datetime :issued_at, null: false
      t.timestamps
    end
    add_index :receipts, :contribution_id, unique: true
    add_index :receipts, :number, unique: true
    add_check_constraint :receipts, "amount_cents > 0", name: "receipts_amount_positive"
  end

  def create_subscriptions_and_benefits
    create_table :subscription_plans do |t|
      t.string :key, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :interval, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :subscription_plans, :key, unique: true
    add_check_constraint :subscription_plans, "amount_cents > 0", name: "subscription_plans_amount_positive"

    create_table :subscriptions do |t|
      t.references :subscription_plan, null: false, foreign_key: true
      t.references :subscriber, polymorphic: true, null: false, index: false
      t.references :campaign, foreign_key: false, index: false
      t.integer :status, null: false, default: 0
      t.date :started_on, null: false
      t.date :next_charge_on, null: false
      t.date :retry_on
      t.date :cancelled_on
      t.integer :cycles_completed, null: false, default: 0
      t.boolean :simulated, null: false, default: true
      t.timestamps
    end
    add_index :subscriptions, %i[subscriber_type subscriber_id status]
    add_index :subscriptions, :campaign_id
    add_index :subscriptions, %i[status next_charge_on]
    add_foreign_key :subscriptions, :campaigns, on_delete: :nullify
    add_check_constraint :subscriptions, "cycles_completed >= 0", name: "subscriptions_cycles_not_negative"

    create_table :subscriber_benefits do |t|
      t.references :subscription, null: false, foreign_key: true, index: false
      t.integer :kind, null: false
      t.date :due_on, null: false
      t.integer :status, null: false, default: 0
      t.datetime :delivered_at
      t.text :content
      t.text :skipped_reason
      t.timestamps
    end
    add_index :subscriber_benefits, %i[subscription_id kind due_on], unique: true,
              name: "index_benefits_on_subscription_kind_due"
    add_index :subscriber_benefits, %i[status due_on]
  end

  def create_budgets_and_expenses
    create_table :budgets do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.bigint :total_cents, null: false, default: 0
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :status, null: false, default: 0
      t.integer :version, null: false, default: 1
      t.timestamps
    end
    add_index :budgets, %i[project_id version], unique: true
    add_check_constraint :budgets, "total_cents >= 0", name: "budgets_total_not_negative"
    add_check_constraint :budgets, "version > 0", name: "budgets_version_positive"

    create_table :budget_lines do |t|
      t.references :budget, null: false, foreign_key: true, index: false
      t.bigint :project_phase_id
      t.integer :category, null: false
      t.string :description, null: false
      t.bigint :estimated_cents, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :budget_lines, %i[budget_id position]
    add_index :budget_lines, :project_phase_id
    add_check_constraint :budget_lines, "estimated_cents >= 0", name: "budget_lines_estimated_not_negative"

    create_table :expenses do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :budget_line, foreign_key: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false, default: "BRL", limit: 3
      t.date :incurred_on, null: false
      t.integer :category, null: false
      t.references :recorded_by, null: false, foreign_key: { to_table: :profiles }
      t.integer :status, null: false, default: 0
      t.integer :sensitivity_level, null: false, default: 1
      t.boolean :simulated, null: false, default: true
      t.timestamps
    end
    add_index :expenses, %i[project_id incurred_on]
    add_foreign_key :expenses, :budget_lines, on_delete: :nullify
    add_check_constraint :expenses, "amount_cents > 0", name: "expenses_amount_positive"
    add_check_constraint :expenses, "sensitivity_level between 0 and 2",
                         name: "expenses_sensitivity_level_valid"
  end

  def create_channels
    create_table :in_kind_donations do |t|
      t.references :donor, polymorphic: true, null: false, index: false
      t.bigint :need_id
      t.references :campaign, foreign_key: false, index: false
      t.integer :category, null: false
      t.string :title, null: false
      t.integer :quantity, null: false, default: 1
      t.string :unit
      t.bigint :estimated_value_cents
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :status, null: false, default: 0
      t.date :expected_on
      t.date :delivered_on
      t.string :decline_reason
      t.timestamps
    end
    add_index :in_kind_donations, %i[donor_type donor_id status]
    add_index :in_kind_donations, :campaign_id
    add_index :in_kind_donations, %i[need_id status]
    add_foreign_key :in_kind_donations, :campaigns, on_delete: :nullify
    add_check_constraint :in_kind_donations, "quantity > 0", name: "in_kind_donations_quantity_positive"
    add_check_constraint :in_kind_donations,
                         "estimated_value_cents is null or estimated_value_cents >= 0",
                         name: "in_kind_donations_value_not_negative"

    create_table :partnerships do |t|
      t.references :organization, null: false, foreign_key: true, index: false
      t.integer :kind, null: false
      t.integer :tier, null: false, default: 0
      t.date :starts_on, null: false
      t.date :ends_on
      t.integer :status, null: false, default: 0
      t.references :owner, foreign_key: false
      t.integer :sensitivity_level, null: false, default: 1
      t.timestamps
    end
    add_index :partnerships, %i[organization_id status]
    add_index :partnerships, %i[kind tier status]
    add_foreign_key :partnerships, :profiles, column: :owner_id, on_delete: :nullify
    add_check_constraint :partnerships, "sensitivity_level between 0 and 2",
                         name: "partnerships_sensitivity_level_valid"

    create_table :events do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :kind, null: false
      t.references :campaign, foreign_key: false, index: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :location_name
      t.references :country, foreign_key: true
      t.integer :capacity
      t.bigint :ticket_price_cents, null: false, default: 0
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :status, null: false, default: 0
      t.boolean :online, null: false, default: false
      t.integer :sensitivity_level, null: false, default: 1
      t.timestamps
    end
    add_index :events, :slug, unique: true
    add_foreign_key :events, :campaigns, on_delete: :nullify
    add_index :events, :campaign_id
    add_check_constraint :events, "ticket_price_cents >= 0", name: "events_ticket_price_not_negative"
    add_check_constraint :events, "capacity is null or capacity > 0", name: "events_capacity_positive"
    add_check_constraint :events, "sensitivity_level between 0 and 2", name: "events_sensitivity_level_valid"

    create_table :event_registrations do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.references :profile, null: false, foreign_key: true
      t.references :contribution, foreign_key: false, index: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    add_index :event_registrations, %i[event_id profile_id], unique: true
    add_index :event_registrations, :contribution_id, unique: true
    add_foreign_key :event_registrations, :contributions, on_delete: :nullify
  end
end
