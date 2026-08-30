# frozen_string_literal: true

class CreateDisbursements < ActiveRecord::Migration[8.1]
  TABLE_COLUMNS = [
    [:references, :ngo, { null: false, foreign_key: true, index: false }],
    [:references, :campaign, { foreign_key: false, index: false }],
    [:string, :reference, { null: false }],
    [:string, :description, { null: false }],
    [:bigint, :amount_cents, { null: false }],
    [:string, :currency, { null: false, default: "BRL", limit: 3 }],
    [:date, :scheduled_on, { null: false }],
    [:date, :executed_on, {}],
    [:integer, :status, { null: false, default: 0 }],
    [:boolean, :simulated, { null: false, default: true }],
    [:integer, :sensitivity_level, { null: false, default: 1 }],
  ].freeze

  def change
    create_disbursements
    add_indexes
    add_foreign_key :disbursements, :campaigns, on_delete: :nullify
    add_constraints
  end

  private

  def create_disbursements
    create_table(:disbursements) do |table|
      TABLE_COLUMNS.each { |type, name, options| table.public_send(type, name, **options) }
      table.timestamps
    end
  end

  def add_indexes
    add_index :disbursements, :reference, unique: true
    add_index :disbursements, %i[ngo_id status]
    add_index :disbursements, %i[status scheduled_on]
  end

  def add_constraints
    add_check_constraint :disbursements, "amount_cents > 0", name: "disbursements_amount_positive"
    add_check_constraint :disbursements, "sensitivity_level between 0 and 2",
                         name: "disbursements_sensitivity_level_valid"
  end
end
