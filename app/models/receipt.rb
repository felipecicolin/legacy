# frozen_string_literal: true

# Comprovante imutável de uma contribuição confirmada.
class Receipt < ApplicationRecord
  belongs_to :contribution
  has_one_attached :pdf

  attr_readonly :number, :issued_year, :sequence_number, :amount_cents, :currency,
                :simulated, :issued_at

  validates :number, :issued_year, :amount_cents, :currency, :issued_at, presence: true
  validates :number, uniqueness: true
  validates :contribution_id, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, length: { is: 3 }, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }
  validates :simulated, inclusion: { in: [true, false] }
  validate :contribution_is_confirmed

  before_validation :copy_contribution_details, on: :create
  before_validation :assign_number, on: :create
  after_create :attach_generated_pdf

  def simulated_mark
    return unless simulated

    I18n.t("receipts.simulated_mark")
  end

  def donor
    contribution.contributor
  end

  private

  def copy_contribution_details
    return unless contribution

    self.amount_cents ||= contribution.amount_cents
    self.currency ||= contribution.currency
    self.issued_at ||= Time.current
    self.simulated = contribution.simulated
  end

  def assign_number
    return if issued_at.blank?

    self.issued_year ||= issued_at.year
    return if number.present?

    sequence = self.class.connection.select_value("select nextval('receipts_sequence_number_seq')")
    self.number = format("%<year>d-%<sequence>06d", year: issued_year, sequence: sequence)
  end

  def contribution_is_confirmed
    return if contribution.blank? || contribution.confirmed?

    errors.add(:contribution, :not_confirmed)
  end

  def attach_generated_pdf
    return if pdf.attached?

    pdf.attach(io: StringIO.new(pdf_content), filename: "#{number}.pdf", content_type: "application/pdf")
  end

  def pdf_content
    "%PDF-1.4\n#{simulated_mark}\n#{number}\n%%EOF\n"
  end
end
