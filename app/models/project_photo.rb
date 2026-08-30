# frozen_string_literal: true

# Foto de obra: ingestão limpa, arquivo original preservado e variantes sob demanda.
class ProjectPhoto < ApplicationRecord
  CATEGORIES = { before: 0, during: 1, after: 2, detail: 3, team: 4 }.freeze
  VARIANT_WIDTHS = [480, 960, 1440].freeze
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_FILE_SIZE = 10.megabytes

  include ScrubbedPhoto

  belongs_to :project
  belongs_to :progress_report, optional: true
  belongs_to :taken_by, class_name: "Profile", optional: true, inverse_of: :taken_project_photos

  attaches_scrubbed_photo :image

  enum :category, CATEGORIES, validate: true

  scope :ordered, -> { order(:category, :position, :id) }

  validates :taken_on, :category, presence: true
  validates :taken_on, comparison: { less_than_or_equal_to: -> { Date.current } }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :progress_report_belongs_to_project
  validate :image_present
  validate :image_is_allowed

  def card_variant(width: 960)
    image.variant(resize_to_fill: [width, (width * 9.0 / 16).round])
  end

  def variant_for(width)
    image.variant(resize_to_limit: [width, nil])
  end

  def visibility_subject = project

  def category_label
    I18n.t(category, scope: :categories)
  end

  private

  def progress_report_belongs_to_project
    return if progress_report.blank? || progress_report.project_id == project_id

    errors.add(:progress_report, :invalid)
  end

  def image_present
    errors.add(:image, :blank) unless image.attached?
  end

  def image_is_allowed
    return unless image.attached?

    blob = image.blob
    errors.add(:image, :content_type) unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
    errors.add(:image, :too_large) if blob.byte_size > MAX_FILE_SIZE
  end
end
