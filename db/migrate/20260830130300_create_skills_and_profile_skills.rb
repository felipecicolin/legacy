# frozen_string_literal: true

class CreateSkillsAndProfileSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      # A chave é estável e em inglês; o rótulo mora no locale de vocabulário.
      t.string :key, null: false
      t.string :category, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps

      t.index :key, unique: true
      t.index %i[category position]
    end

    create_table :profile_skills do |t|
      # O índice composto abaixo já cobre a FK de profile; skill precisa de um
      # índice próprio para que a FK continue indexada sem redundância.
      t.references :profile, null: false, foreign_key: true, index: false
      t.references :skill, null: false, foreign_key: true
      t.integer :proficiency, null: false
      t.integer :years_of_experience

      t.timestamps

      t.index %i[profile_id skill_id], unique: true
    end
  end
end
