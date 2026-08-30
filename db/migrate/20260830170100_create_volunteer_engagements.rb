# frozen_string_literal: true

class CreateVolunteerEngagements < ActiveRecord::Migration[8.1]
  def change
    create_volunteer_groups
    create_engagements
  end

  private

  # O grupo corporativo é o quarto modelo do material institucional: empresa,
  # igreja ou universidade enviando gente em bloco. Ele tem janela de
  # disponibilidade porque é ela que casa — ou não — com o prazo da necessidade.
  def create_volunteer_groups
    create_table :volunteer_groups do |t|
      t.references :organization, null: false, foreign_key: true, index: false
      t.references :coordinator, null: false, foreign_key: { to_table: :profiles }
      t.string :name, null: false
      t.integer :expected_size
      t.date :available_from
      t.date :available_until
      t.integer :group_status, null: false, default: 0

      t.timestamps
    end

    add_index :volunteer_groups, %i[organization_id group_status]
    add_check_constraint :volunteer_groups, "expected_size is null or expected_size > 0",
                         name: "volunteer_groups_expected_size_is_positive"
    add_check_constraint :volunteer_groups,
                         "available_until is null or available_from is null or available_until >= available_from",
                         name: "volunteer_groups_window_ends_after_it_starts"
  end

  def create_engagements
    create_table :volunteer_engagements do |t|
      t.references :profile, null: false, foreign_key: true, index: false
      # A organização de origem some e o voluntariado continua: a pessoa
      # segue voluntária, só deixa de ser "pela empresa X".
      t.references :organization, foreign_key: { on_delete: :nullify }
      t.references :volunteer_group, foreign_key: true
      t.integer :engagement_model, null: false
      t.integer :engagement_area, null: false
      t.integer :engagement_status, null: false, default: 0
      t.date :started_on, null: false
      t.date :ended_on
      t.integer :weekly_hours

      t.timestamps
    end

    add_index :volunteer_engagements, %i[profile_id engagement_status]
    add_index :volunteer_engagements, %i[engagement_model engagement_area engagement_status]
    add_check_constraint :volunteer_engagements, "ended_on is null or ended_on >= started_on",
                         name: "volunteer_engagements_end_after_it_starts"
    add_check_constraint :volunteer_engagements, "weekly_hours is null or weekly_hours between 1 and 168",
                         name: "volunteer_engagements_weekly_hours_within_a_week"
  end
end
