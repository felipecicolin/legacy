# frozen_string_literal: true

# Campanhas que podem ser detalhadas pelo contexto atual e o agregado das que
# não podem. O agregado nunca traz título, ONG ou projeto confidencial.
class FundraisingCampaigns
  Row = Data.define(:title, :ngo_name, :goal_cents, :cash_raised_cents,
                    :in_kind_raised_cents, :progress_percentage, :ends_on, :status,
                    :status_label)
  Aggregate = Data.define(:count, :goal_cents, :cash_raised_cents, :in_kind_raised_cents)

  def initialize(visibility)
    @visibility = visibility
  end

  def rows
    @rows ||= build_rows
  end

  def hidden
    @hidden ||= self.class.aggregate(hidden_scope)
  end

  def self.aggregate(scope)
    ids = scope.select(:id)
    Aggregate.new(count: scope.count, goal_cents: scope.sum(:goal_cents),
                  cash_raised_cents: Contribution.confirmed.where(campaign_id: ids).sum(:amount_cents),
                  in_kind_raised_cents: InKindDonation.accepted_for_total.where(campaign_id: ids)
                                                      .sum(:estimated_value_cents))
  end

  def self.amounts_by_campaign(relation, ids)
    return {} if ids.empty?

    amount_column = relation.klass == Contribution ? :amount_cents : :estimated_value_cents
    relation.where(campaign_id: ids).group(:campaign_id).sum(amount_column)
  end

  def self.progress_for(cash_cents, goal_cents)
    [cash_cents * 100 / goal_cents, 100].min
  end

  def self.row_for(campaign, cash, in_kind)
    cash_cents = cash.fetch(campaign.id, 0)
    Row.new(title: campaign.title, ngo_name: campaign.ngo.name, goal_cents: campaign.goal_cents,
            cash_raised_cents: cash_cents, in_kind_raised_cents: in_kind.fetch(campaign.id, 0),
            progress_percentage: progress_for(cash_cents, campaign.goal_cents), ends_on: campaign.ends_on,
            status: campaign.status, status_label: campaign.status_label)
  end

  private

  def build_rows
    scope = visible_scope
    campaigns = scope.includes(:ngo).order(:ends_on, :created_at).to_a
    amounts = amounts_for(campaigns)

    campaigns.map { |campaign| self.class.row_for(campaign, *amounts) }
  end

  def amounts_for(campaigns)
    ids = campaigns.map(&:id)
    [self.class.amounts_by_campaign(Contribution.confirmed, ids),
     self.class.amounts_by_campaign(InKindDonation.accepted_for_total, ids)]
  end

  def visible_scope
    Campaign.where(sensitivity_level: @visibility.allowed_levels)
            .where(ngo_id: Ngo.where(sensitivity_level: @visibility.allowed_levels).select(:id))
  end

  def hidden_scope
    Campaign.where.not(id: visible_scope.select(:id))
  end
end
