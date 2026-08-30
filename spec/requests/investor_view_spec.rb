# frozen_string_literal: true

require "rails_helper"

# A dash do investidor: quanto entrou, em que obras, e quantas pessoas a fatia
# dele alcança. Ver docs/investor-dashboard.md.
RSpec.describe "Investor view" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password: password) }
  let(:profile) { create(:profile, user: user) }
  let(:ngo) { create(:ngo, :active) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: password }
  end

  # Entrar não é ter perfil. Quem chegou sem um precisa de caminho, não de um
  # painel de zeros que se lê como "seu dinheiro sumiu".
  it "offers a way in to someone who signed in without a profile" do
    sign_in

    get investor_path

    expect(response.body).to include(I18n.t("investors.no_profile.empty_title"))
  end

  it "says there is nothing yet instead of showing a screen full of zeroes" do
    profile
    sign_in

    get investor_path

    expect(response.body).to include(I18n.t("investors.show.empty_title"))
  end

  it "shows the total, the funded project and the attributed reach" do
    project = create(:project, ngo: ngo, funding_target_cents: 100_000, estimated_annual_reach: 15_000)
    campaign = create(:campaign, ngo: ngo, project: project)
    create(:contribution, :confirmed, campaign: campaign, contributor: profile, amount_cents: 25_000)
    sign_in

    get investor_path

    aggregate_failures do
      expect(response.body).to include(project.title)
      expect(response.body).to include("250,00")
      expect(response.body).to include("3.750")
    end
  end

  # A obra que o leitor não alcança não aparece nem pelo nome: a prestação de
  # contas vira agregado, e a obra não vira alvo.
  it "replaces a project it cannot reach with an anonymised line" do
    InvestorDashboard::MINIMUM_AGGREGATE_COUNT.times do
      home = create(:ngo, :active, country: create(:country, high_risk: true))
      project = create(:project, ngo: home, funding_target_cents: 100_000, estimated_annual_reach: 15_000)
      create(:contribution, :confirmed, campaign: create(:campaign, ngo: home, project: project),
                                        contributor: profile, amount_cents: 25_000)
    end
    sign_in

    get investor_path

    aggregate_failures do
      expect(response.body).not_to include("Reforma do telhado")
      expect(response.body).to include(I18n.t("investors.show.projects_title"))
    end
  end

  it "sends someone who never signed in to the door" do
    get investor_path

    expect(response).to redirect_to(new_session_path)
  end
end
