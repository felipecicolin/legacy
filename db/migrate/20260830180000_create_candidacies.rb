# frozen_string_literal: true

class CreateCandidacies < ActiveRecord::Migration[8.1]
  def change
    # O gate de registro profissional é da NECESSIDADE, e não do papel: quem
    # decide se aquela vaga exige CREA é quem a abriu. Ver docs/mobilization.md.
    add_column :needs, :requires_professional_registration, :boolean, null: false, default: false

    create_table :candidacies do |t|
      t.references :need, null: false, foreign_key: true, index: false
      t.references :profile, foreign_key: true, index: false
      t.references :volunteer_group, foreign_key: true, index: false
      t.integer :candidacy_status, null: false, default: 0
      t.integer :rejection_reason
      t.datetime :decided_at
      t.references :decided_by, foreign_key: { to_table: :profiles }

      t.timestamps
    end

    add_candidacy_indexes
    add_candidacy_constraints
  end

  private

  # Índices únicos PARCIAIS: a candidatura é de pessoa OU de grupo, nunca dos
  # dois, e o `where:` é a forma de dizer isso no banco em vez de só na
  # validação. Um índice sobre as duas colunas juntas deixaria passar duas
  # candidaturas da mesma pessoa quando o grupo fosse nulo nas duas.
  def add_candidacy_indexes
    add_index :candidacies, %i[need_id candidacy_status]
    add_index :candidacies, %i[profile_id need_id], unique: true, where: "profile_id is not null"
    add_index :candidacies, %i[volunteer_group_id need_id], unique: true,
                            where: "volunteer_group_id is not null"
  end

  def add_candidacy_constraints
    add_check_constraint :candidacies,
                         "(profile_id is null) <> (volunteer_group_id is null)",
                         name: "candidacies_have_exactly_one_candidate"
  end
end
