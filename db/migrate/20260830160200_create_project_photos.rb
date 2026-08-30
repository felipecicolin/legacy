# frozen_string_literal: true

class CreateProjectPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :project_photos do |t|
      t.references :project, null: false, foreign_key: true, index: false
      # Opcional: foto avulsa da obra existe, e ela não é um relatório. Os dois
      # `on_delete: :nullify` casam com o `dependent: :nullify` dos modelos —
      # sem eles, um DELETE fora do Active Record reprovaria na FK em vez de
      # soltar a foto, que é o que se quer: a imagem da obra sobrevive ao
      # relatório que a acompanhava e a quem a tirou.
      t.references :progress_report, foreign_key: { on_delete: :nullify }
      t.references :taken_by, foreign_key: { to_table: :profiles, on_delete: :nullify }
      t.date :taken_on, null: false
      t.string :caption
      t.integer :category, null: false, default: 0
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :project_photos, %i[project_id category position]

    add_check_constraint :project_photos, "position >= 0", name: "project_photos_position_not_negative"
  end
end
