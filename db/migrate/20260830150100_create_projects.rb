# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      add_identity_columns(t)
      add_schedule_columns(t)
      t.bigint :funding_target_cents, null: false, default: 0
      t.string :currency, null: false, default: "BRL", limit: 3
      t.integer :physical_progress, null: false, default: 0

      t.timestamps
    end

    add_project_indexes
    add_project_constraints
  end

  private

  # `code_number` é `serial`, e não um `maximum(:code) + 1` em Ruby: duas
  # criações simultâneas leem o mesmo máximo e produzem o mesmo código, e o
  # índice único transforma isso em exceção de driver no meio do request. A
  # sequence do Postgres é atômica e não bloqueia.
  #
  # A sequence é declarada como DEFAULT DA COLUNA, e não solta com um
  # `CREATE SEQUENCE`: o dumper Ruby do Rails não escreve sequence avulsa no
  # `db/schema.rb`, e o banco de teste — que nasce do schema, não das
  # migrations — subiria sem ela. Presa à coluna, ela é dumpada como `t.serial`.
  #
  # `code` é coluna GERADA pelo banco. Assim ela é indexável e buscável como
  # qualquer string, e a imutabilidade que a issue pede não depende de
  # `attr_readonly` nem de callback: o Postgres recusa escrita em coluna
  # generated, inclusive por `update_all` e por SQL cru.
  def add_identity_columns(table)
    table.column :code_number, :serial, null: false
    table.virtual :code, type: :string, stored: true,
                         as: "'OB-' || lpad(code_number::text, 4, '0')"
    table.string :title, null: false
    table.references :mission_base, null: false, foreign_key: true, index: false
    table.integer :status, null: false, default: 0
    table.integer :sensitivity_level, null: false, default: Sensitive::LEVELS.fetch(:restricted)
  end

  def add_schedule_columns(table)
    table.date :planned_start_on
    table.date :planned_end_on
    table.date :actual_start_on
    table.date :actual_end_on
  end

  def add_project_indexes
    add_index :projects, :code, unique: true
    add_index :projects, %i[mission_base_id status]
    add_index :projects, %i[status sensitivity_level]
  end

  # Sem a constraint de coordenada do `Sensitive`: `projects` não guarda
  # nenhuma das colunas que ela restringe — endereço e coordenada moram na
  # base. A constraint restringe colunas, e numa tabela sem elas não há o que
  # restringir; o lado Ruby do concern já intersecta com o schema real. Se um
  # dia a obra ganhar endereço próprio, ela vem junto.
  def add_project_constraints
    add_check_constraint :projects, "physical_progress between 0 and 100",
                         name: "projects_physical_progress_within_range"
    add_check_constraint :projects, "funding_target_cents >= 0",
                         name: "projects_funding_target_not_negative"
  end
end
