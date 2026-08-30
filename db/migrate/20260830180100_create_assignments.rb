# frozen_string_literal: true

class CreateAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :assignments do |t|
      t.references :candidacy, null: false, foreign_key: true, index: { unique: true }
      t.references :need, null: false, foreign_key: true, index: false
      t.integer :quantity, null: false, default: 1
      t.date :starts_on, null: false
      t.date :ends_on
      t.integer :assignment_status, null: false, default: 0

      t.timestamps
    end

    add_index :assignments, %i[need_id assignment_status]
    add_check_constraint :assignments, "quantity > 0", name: "assignments_quantity_is_positive"
    add_check_constraint :assignments, "ends_on is null or ends_on >= starts_on",
                         name: "assignments_ends_after_it_starts"

    create_fulfillments
  end

  private

  # Polimórfico DE PROPÓSITO, e é a única vez que este repositório escolhe
  # polimorfismo: necessidade de material é abatida por doação, a de recurso
  # por contribuição financeira, a de mão de obra por alocação. Três origens,
  # UM mecanismo de abatimento — senão cada espécie de necessidade ganha a sua
  # própria contabilidade e elas divergem.
  #
  # A diferença para o caso que `Need` recusou: lá havia UM dono real com um
  # qualificador opcional; aqui são três tipos genuinamente distintos, e
  # nenhum deles é "o" dono.
  def create_fulfillments
    create_table :need_fulfillments do |t|
      t.references :need, null: false, foreign_key: true, index: false
      t.references :source, polymorphic: true, null: false, index: false
      t.integer :quantity, null: false
      t.datetime :fulfilled_at, null: false

      t.timestamps
    end

    # Uma origem abate uma necessidade uma vez: sem isto, um `create` repetido
    # por retentativa de job dobraria o abatimento em silêncio.
    add_index :need_fulfillments, %i[need_id source_type source_id], unique: true

    # A busca pela ORIGEM não é servida pelo índice acima, cujo prefixo é
    # `need_id`: `assignment.need_fulfillment` procura por origem, e sem este
    # índice varreria a tabela.
    add_index :need_fulfillments, %i[source_type source_id]
    add_check_constraint :need_fulfillments, "quantity > 0", name: "need_fulfillments_quantity_is_positive"
  end
end
