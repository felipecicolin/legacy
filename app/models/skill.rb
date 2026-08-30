# frozen_string_literal: true

# Habilidade da taxonomia curada. O rótulo não é armazenado: a chave estável
# aponta para o locale, e o seed lê a lista de db/vocabulary/skills.yml.
class Skill < ApplicationRecord
  CATEGORIES = %w[architecture engineering support trade].freeze

  has_many :profile_skills, dependent: :destroy, inverse_of: :skill
  has_many :profiles, through: :profile_skills
  has_many :needs, dependent: :restrict_with_error

  validates :key, :category, presence: true
  validates :key, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [true, false] }

  # O seed atualiza a linha existente para que o YAML continue sendo a fonte
  # da categoria, da posição e da ativação da habilidade.
  def self.load_vocabulary!
    Vocabulary::Catalog.skills.entries.each do |entry|
      find_or_initialize_by(key: entry.fetch(:key)).update!(entry)
    end
  end

  def name
    I18n.t(key, scope: :skills)
  end

  def category_label
    I18n.t(category, scope: :skill_categories)
  end
end
