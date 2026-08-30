# frozen_string_literal: true

class SubscriberBenefit < ApplicationRecord
  KINDS = { monthly_report: 0, semiannual_gift: 1 }.freeze
  STATUSES = { pending: 0, prepared: 1, delivered: 2, skipped: 3 }.freeze

  belongs_to :subscription

  enum :kind, KINDS, validate: true
  enum :status, STATUSES, validate: true

  scope :due, -> { pending.where(due_on: ..Date.current) }
  scope :monthly_reports, -> { where(kind: :monthly_report) }
  scope :gifts, -> { where(kind: :semiannual_gift) }

  validates :kind, :due_on, :status, presence: true
  validates :subscription_id, uniqueness: { scope: %i[kind due_on] }
  validates :due_on, comparison: { greater_than_or_equal_to: ->(benefit) { benefit.subscription.started_on } }
  validates :delivered_at, presence: true, if: :delivered?
  validate :content_is_present_when_prepared

  def self.create_for_cycle!(subscription, due_on)
    create!(subscription:, kind: :monthly_report, due_on:)
    return unless (subscription.cycles_completed % 6).zero?

    create!(subscription:, kind: :semiannual_gift, due_on:)
  end

  def self.skip_gift_for!(subscription, reason)
    gift = find_or_initialize_by(subscription:, kind: :semiannual_gift, due_on: Date.current)
    gift.assign_attributes(status: :skipped, skipped_reason: reason)
    gift.save!
  end

  def prepare(context: Visibility::Context.anonymous)
    update!(status: :prepared, content: report_body(context:))
  end
  alias prepare! prepare

  def deliver
    update!(status: :delivered, delivered_at: Time.current)
  end
  alias deliver! deliver

  def delivery_address
    user = subscription.subscriber.try(:user)

    user&.email_address
  end

  def skip(reason:)
    update!(status: :skipped, skipped_reason: reason)
  end
  alias skip! skip

  def report_body(context: Visibility::Context.anonymous)
    return I18n.t("benefits.monthly_report.gift") unless monthly_report?
    return I18n.t("benefits.monthly_report.restricted") unless campaign_visible?(context)

    report = latest_report
    return I18n.t("benefits.monthly_report.no_updates") unless report

    I18n.t("benefits.monthly_report.updated", progress: report.physical_progress)
  end

  private

  def campaign
    subscription.campaign
  end

  def campaign_visible?(context)
    campaign.present? && context.can_identify?(campaign)
  end

  def latest_report
    return unless campaign&.project

    campaign.project.progress_reports.approved.where(reported_on: report_period).latest_first.first
  end

  def report_period
    due_on.prev_month.beginning_of_month..due_on
  end

  def content_is_present_when_prepared
    return unless prepared? && content.blank?

    errors.add(:content, :blank)
  end
end
