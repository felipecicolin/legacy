# frozen_string_literal: true

# Habilidade que uma pessoa declarou, com o nível de domínio e a experiência.
class ProfileSkill < ApplicationRecord
  belongs_to :profile, inverse_of: :profile_skills
  belongs_to :skill, inverse_of: :profile_skills

  enum :proficiency, {
    beginner: 0,
    intermediate: 1,
    advanced: 2,
    expert: 3,
  }, validate: true

  validates :profile_id, uniqueness: { scope: :skill_id }
  validates :proficiency, presence: true
  validates :years_of_experience, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def proficiency_label
    I18n.t(proficiency, scope: :proficiencies)
  end
end
