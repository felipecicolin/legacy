# frozen_string_literal: true

class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      # Índice único: uma pessoa tem no máximo um perfil. A trava é do banco,
      # não uma validação de unicidade — validação perde a corrida entre dois
      # requests concorrentes, o índice não.
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # `legal_name` nunca é exibido publicamente; `display_name` é o que a UI
      # mostra. Armazenado, e não derivado, para que trocar o nome legal não
      # reescreva retroativamente todo o histórico já exibido.
      t.string :legal_name, null: false
      t.string :display_name, null: false

      t.string :headline
      t.string :phone

      t.string :preferred_locale, null: false, default: "pt-BR"
      t.string :timezone, null: false, default: "America/Sao_Paulo"

      t.timestamps
    end
  end
end
