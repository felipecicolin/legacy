# frozen_string_literal: true

class CreateDeployments < ActiveRecord::Migration[8.1]
  def change
    create_deployments
    create_deployment_members
  end

  private

  # A base é obrigatória e a obra não: envio para levantar uma base ainda sem
  # obra aberta é o caso normal, não a exceção — é a mesma separação que
  # `Need` faz.
  #
  # Sem `TravelDocument`: passaporte, visto, vacina e seguro digitalizados
  # adicionam superfície de dado pessoal sensível — com retenção, acesso
  # restrito e LGPD junto — para uma demonstração que não envia ninguém a lugar
  # nenhum. Uma demo deve carregar MENOS dado sensível, não mais.
  def create_deployments
    create_table :deployments do |t|
      t.references :mission_base, null: false, foreign_key: true, index: false
      # `on_delete: :nullify` casa com o `dependent: :nullify` do modelo: o
      # envio sobrevive à obra — ele foi para a base, e o registro logístico
      # é histórico.
      t.references :project, foreign_key: { on_delete: :nullify }
      t.string :name, null: false
      t.date :departs_on, null: false
      t.date :returns_on, null: false
      t.integer :capacity
      t.integer :deployment_status, null: false, default: 0
      t.bigint :cost_per_person_cents
      t.string :currency, null: false, default: "BRL", limit: 3

      t.timestamps
    end

    add_index :deployments, %i[mission_base_id deployment_status]
    add_check_constraint :deployments, "returns_on >= departs_on", name: "deployments_returns_after_it_departs"
    add_check_constraint :deployments, "capacity is null or capacity > 0", name: "deployments_capacity_is_positive"
    add_check_constraint :deployments, "cost_per_person_cents is null or cost_per_person_cents >= 0",
                         name: "deployments_cost_not_negative"
  end

  def create_deployment_members
    create_table :deployment_members do |t|
      t.references :deployment, null: false, foreign_key: true, index: false
      t.references :profile, null: false, foreign_key: true
      t.integer :member_role, null: false
      t.integer :member_status, null: false, default: 0

      t.timestamps
    end

    add_index :deployment_members, %i[deployment_id profile_id], unique: true
  end
end
