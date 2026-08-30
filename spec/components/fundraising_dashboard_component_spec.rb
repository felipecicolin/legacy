# frozen_string_literal: true

require "rails_helper"

RSpec.describe FundraisingDashboardComponent, type: :component do
  let(:campaign) { create(:campaign, title: "Campanha visível", ends_on: nil) }
  let(:admin_context) do
    user = create(:user)
    create(:staff_role, :admin, user:)
    Authorization::Context.for(user)
  end
  let(:support_user) { create(:user) }

  before do
    create(:contribution, :confirmed, campaign:, amount_cents: 18_400)
    create(:contribution, :confirmed, campaign:, amount_cents: 7_500, origin: :event)
    create(:in_kind_donation, campaign:, status: :accepted, category: :material, estimated_value_cents: 12_000)
    create(:in_kind_donation, campaign:, status: :accepted, category: :expertise, unit: "hora",
                              estimated_value_cents: 8_000)
    create(:in_kind_donation, campaign:, status: :offered, estimated_value_cents: nil)
    create(:in_kind_donation, campaign:, status: :in_transit)
    create(:in_kind_donation, campaign:, status: :delivered, delivered_on: Date.current)
    create(:in_kind_donation, campaign:, status: :declined, decline_reason: "Sem disponibilidade")
    create(:subscription, status: :active)
    create(:subscription, status: :past_due)
    create(:subscription, status: :cancelled)
    create(:subscription, status: :paused)
    create(:subscriber_benefit, subscription: Subscription.active.last, kind: :monthly_report)
    create(:disbursement, ngo: campaign.ngo)
    create(:disbursement, :executed, ngo: campaign.ngo)
    create(:disbursement, ngo: campaign.ngo, status: :cancelled)
  end

  it "renders every financial section with separated, simulated values" do
    render_inline(described_class.new(presenter: FundraisingDashboard.new(admin_context)))

    expect_financial_sections
  end

  it "aggregates confidential campaigns and never names an anonymous donor" do
    seed_confidential_data
    render_inline(described_class.new(presenter: FundraisingDashboard.new(support_context)))

    expect_confidential_data_to_be_aggregated
  end

  private

  def expect_financial_sections
    expect_header_and_simulation
    expect_separated_totals
    expect_campaign_and_subscription_sections
    expect_in_kind_and_disbursement_sections
  end

  def expect_confidential_data_to_be_aggregated
    expect(page.text).not_to include("Título confidencial", "Doador que não pode aparecer")
    expect(page.text).to include("campanhas confidenciais em agregado", "repasses restritos em agregado")
  end

  def expect_header_and_simulation
    expect(page).to have_css("h1", text: "Painel de arrecadação")
    expect(page).to have_css("[data-simulated='true']", minimum: 5)
    expect(page).to have_text("DADOS SIMULADOS — sem valor financeiro real")
  end

  def expect_separated_totals
    expect(page.text).to include("R$ 259,00", "R$ 240,00", "Em dinheiro", "Em espécie")
  end

  def expect_campaign_and_subscription_sections
    expect(page).to have_text("Campanha visível")
    expect(page).to have_css("[data-status='past_due'].bg-warning-soft", minimum: 1)
    expect(page).to have_text("Próximos benefícios")
  end

  def expect_in_kind_and_disbursement_sections
    expect(page.text).to include("Materiais e equipamentos", "Inteligência e serviços", "Repasses")
    expect(page).to have_css("svg[role='img']")
  end

  def seed_confidential_data
    hidden = create(:campaign, title: "Título confidencial", sensitivity_level: :confidential)
    contributor = create(:profile, display_name: "Doador que não pode aparecer")
    create(:contribution, :confirmed, campaign: hidden, anonymous: true, contributor:)
    hidden_ngo = create(:ngo, :active, sensitivity_level: :confidential)
    create(:disbursement, ngo: hidden_ngo, sensitivity_level: :confidential)
  end

  def support_context
    create(:staff_role, user: support_user, staff_level: :support)
    Authorization::Context.for(support_user)
  end
end
