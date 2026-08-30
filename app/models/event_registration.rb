# frozen_string_literal: true

class EventRegistration < ApplicationRecord
  STATUSES = { registered: 0, confirmed: 1, attended: 2, no_show: 3, cancelled: 4 }.freeze

  belongs_to :event
  belongs_to :profile
  belongs_to :contribution, optional: true

  enum :status, STATUSES, validate: true

  validates :profile_id, uniqueness: { scope: :event_id }
  validates :contribution_id, uniqueness: true, allow_nil: true
  validate :event_accepts_registration
  validate :capacity_is_available, on: :create
  validate :paid_event_has_campaign

  after_create :create_paid_contribution

  def confirm
    update!(status: :confirmed)
  end
  alias confirm! confirm

  def cancel
    contribution&.refund!
    update!(status: :cancelled)
  end
  alias cancel! cancel

  private

  def create_paid_contribution
    return if event.ticket_price_cents.zero?

    contribution = Contribution.create!(
      campaign: event.campaign, amount_cents: event.ticket_price_cents,
      currency: event.currency, origin: :event, contributor: profile
    )
    contribution.process!
    update!(contribution:, status: contribution.confirmed? ? :confirmed : :registered)
  end

  def event_accepts_registration
    return if event.blank? || event.published? || event.held? || event.cancelled?

    errors.add(:event, :not_open)
  end

  def capacity_is_available
    return if event.blank? || event.capacity_available?

    errors.add(:event, :capacity_reached)
  end

  def paid_event_has_campaign
    return if event.blank? || event.ticket_price_cents.zero? || event.campaign.present?

    errors.add(:event, :campaign_required)
  end
end
