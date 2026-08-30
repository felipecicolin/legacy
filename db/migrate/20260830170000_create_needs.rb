# frozen_string_literal: true

class CreateNeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :needs do |t|
      # Duas chaves REAIS, e não `belongs_to :needable, polymorphic: true`.
      # Toda necessidade pertence a uma base — a que opera a obra, quando há
      # obra. A FK de verdade dá integridade que o banco cobra e transforma
      # "necessidades por país" num join simples, em vez de uma consulta de
      # dois ramos. Ver docs/mobilization.md.
      t.references :mission_base, null: false, foreign_key: true, index: false
      t.references :project, foreign_key: true, index: false
      t.references :skill, foreign_key: true
      add_description_columns(t)
      add_quantity_columns(t)

      t.timestamps
    end

    add_need_indexes
    add_need_constraints
  end

  private

  def add_description_columns(table)
    table.integer :need_kind, null: false
    table.string :title, null: false
    table.integer :urgency, null: false, default: 1
    table.date :needed_by
    table.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)
  end

  def add_quantity_columns(table)
    table.integer :quantity, null: false, default: 1
    table.integer :fulfilled_quantity, null: false, default: 0
    table.integer :need_status, null: false, default: 0
    table.bigint :estimated_value_cents
    table.string :currency, null: false, default: "BRL", limit: 3
  end

  def add_need_indexes
    add_index :needs, %i[mission_base_id need_status]
    add_index :needs, %i[project_id need_status]
    add_index :needs, %i[need_kind need_status urgency]
  end

  # O abatimento nunca passa da quantidade pedida, e a regra é do BANCO: a
  # trava de concorrência do #33 se apoia nela — duas alocações simultâneas na
  # última vaga passam pela validação e é o CHECK que reprova a segunda.
  def add_need_constraints
    add_check_constraint :needs, "quantity > 0", name: "needs_quantity_is_positive"
    add_check_constraint :needs, "fulfilled_quantity between 0 and quantity",
                         name: "needs_fulfilled_within_quantity"
    add_check_constraint :needs, "estimated_value_cents is null or estimated_value_cents >= 0",
                         name: "needs_estimated_value_not_negative"
  end
end
