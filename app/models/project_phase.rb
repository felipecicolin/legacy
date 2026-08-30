# frozen_string_literal: true

# Uma etapa da obra. O avanço ponderado é explicável: cada percentual aparece
# ao lado do peso que formou o total, em vez de esconder uma média numa coluna.
class ProjectPhase < ApplicationRecord
  belongs_to :project
  has_many :budget_lines, dependent: :nullify, inverse_of: :project_phase

  validates :name, presence: true
  validates :weight, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :physical_progress, numericality: { only_integer: true, in: 0..100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def progress = physical_progress
end
