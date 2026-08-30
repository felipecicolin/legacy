# frozen_string_literal: true

# O grupo corporativo: empresa, igreja ou universidade enviando gente em bloco.
# É o quarto modelo de voluntariado do material institucional, e o único que
# não é uma pessoa. Ver docs/mobilization.md.
class VolunteerGroup < ApplicationRecord
  belongs_to :organization
  belongs_to :coordinator, class_name: "Profile", inverse_of: :coordinated_volunteer_groups
  has_many :volunteer_engagements, dependent: :restrict_with_error

  enum :group_status, { forming: 0, available: 1, engaged: 2, disbanded: 3 }, validate: true, prefix: true

  scope :available, -> { group_status_available }

  # A janela existe para casar — ou não — com o prazo da necessidade. Um grupo
  # sem data declarada é considerado disponível: é o caso do grupo que ainda
  # está combinando quando vai, e excluí-lo do matching o tornaria invisível
  # justamente para quem poderia convidá-lo.
  scope :available_on, lambda { |date|
    available.where("available_from is null or available_from <= :date", date: date)
             .where("available_until is null or available_until >= :date", date: date)
  }

  validates :name, presence: true
  validates :expected_size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :window_ends_after_it_starts

  def group_status_label
    I18n.t(group_status, scope: :group_statuses)
  end

  # Range sem começo e sem fim cobre tudo, que é exatamente a semântica de uma
  # janela não declarada — e evita comparar `nil` a mão nos dois extremos.
  def available_on?(date)
    Range.new(available_from, available_until).cover?(date)
  end

  def to_s = name

  private

  def window_ends_after_it_starts
    return if available_until.blank? || available_from.blank? || available_until >= available_from

    errors.add(:available_until, :before_start)
  end
end
