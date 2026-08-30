# frozen_string_literal: true

# A parte não monetária da arrecadação. O valor estimado aparece por categoria,
# mas nunca é acrescentado aos centavos recebidos em dinheiro.
class FundraisingInKind
  MATERIAL_CATEGORIES = %w[material equipment transport].freeze
  INTELLIGENCE_CATEGORIES = %w[expertise service].freeze
  Row = Data.define(:title, :category, :category_label, :estimated_value_cents, :status,
                    :status_label, :expected_on, :delivered_on)

  def material_cents = self.class.value_for(MATERIAL_CATEGORIES)

  def intelligence_cents = self.class.value_for(INTELLIGENCE_CATEGORIES)

  def total_cents = material_cents + intelligence_cents

  def self.value_for(categories)
    InKindDonation.accepted_for_total.where(currency: "BRL", category: categories).sum(:estimated_value_cents)
  end

  def rows
    @rows ||= InKindDonation.order(:status, :expected_on, :created_at).map do |donation|
      Row.new(title: donation.title, category: donation.category, category_label: donation.category_label,
              estimated_value_cents: donation.estimated_value_cents, status: donation.status,
              status_label: I18n.t(donation.status, scope: :statuses), expected_on: donation.expected_on,
              delivered_on: donation.delivered_on)
    end
  end
end
