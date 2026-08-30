# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvestorDashboard do
  subject(:dashboard) { described_class.new(profile, Authorization::Context.for(user)) }

  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }
  let(:ngo) { create(:ngo, :active) }

  # R$ 1.000 de meta, R$ 250 aportados e 15.000 pessoas por ano: um quarto da
  # obra, e portanto 3.750 pessoas atribuídas.
  def funded_project(reach: 15_000, target: 100_000, cents: 25_000, home: nil)
    project = create(:project, ngo: home || ngo, funding_target_cents: target,
                               estimated_annual_reach: reach)
    fund(project, cents)
    project
  end

  def fund(project, cents)
    campaign = create(:campaign, ngo: project.ngo, project: project)
    create(:contribution, :confirmed, campaign: campaign, contributor: profile, amount_cents: cents)
  end

  def confidential_ngo
    create(:ngo, :active, country: create(:country, high_risk: true))
  end

  it "does not call someone an investor before the first confirmed contribution" do
    create(:contribution, contributor: profile, amount_cents: 9_900)

    expect(dashboard).not_to be_investor
  end

  # `counted` é o escopo do próprio `Contribution`. Contribuição pendente é
  # intenção, não aporte.
  it "counts only confirmed money in the total" do
    funded_project(cents: 25_000)
    create(:contribution, contributor: profile, amount_cents: 9_900)

    expect(dashboard.invested_cents).to eq(25_000)
  end

  it "attributes reach in proportion to the share that was funded" do
    funded_project

    expect(dashboard.people_reached).to eq(3_750)
  end

  # Dividir por zero é o primeiro jeito de a tela explodir: a coluna nasce em
  # zero e a CHECK permite.
  it "attributes no reach to a project with no funding target" do
    funded_project(target: 0)

    expect(dashboard.people_reached).to eq(0)
  end

  it "attributes no reach to a project with no estimate recorded" do
    funded_project(reach: nil)

    expect(dashboard.people_reached).to eq(0)
  end

  it "leaves a finished project out of the active list" do
    project = funded_project
    project.update!(status: :in_progress)
    project.update!(status: :completed)

    expect(dashboard.active_stakes).to be_empty
  end

  # Dinheiro que entrou em campanha sem obra é real e conta no total. Somá-lo
  # às obras inflaria a conta; omiti-lo faria os números não fecharem.
  it "reports money that landed on a campaign with no project" do
    create(:contribution, :confirmed, campaign: create(:campaign, ngo: ngo),
                                      contributor: profile, amount_cents: 40_000)

    expect([dashboard.invested_cents, dashboard.unlinked_cents]).to eq([40_000, 40_000])
  end

  it "keeps the total exact even for a project the reader cannot reach" do
    funded_project(home: confidential_ngo)

    expect(dashboard.invested_cents).to eq(25_000)
  end

  describe "a project the reader cannot reach" do
    # Três é o piso do agregado de campanha, e é o mesmo aqui: um agregado de
    # uma obra só descreveria justamente a obra que o nível esconde.
    before { described_class::MINIMUM_AGGREGATE_COUNT.times { funded_project(home: confidential_ngo) } }

    it "never appears itemised" do
      expect(dashboard.stakes).to be_empty
    end

    it "is folded into the totals as an anonymised aggregate" do
      aggregate_failures do
        expect(dashboard).to be_hidden_disclosable
        expect(dashboard.people_reached).to eq(3_750 * described_class::MINIMUM_AGGREGATE_COUNT)
        expect(dashboard.active_count).to eq(described_class::MINIMUM_AGGREGATE_COUNT)
      end
    end
  end

  describe "too few projects to anonymise" do
    before { funded_project(home: confidential_ngo) }

    # O número menor precisa vir com a explicação: sozinho ele se lê como
    # número errado, e a pessoa vai procurar o dinheiro que "sumiu".
    it "is withheld from the totals and said so" do
      aggregate_failures do
        expect(dashboard).to be_hidden_withheld
        expect(dashboard).not_to be_hidden_disclosable
        expect([dashboard.people_reached, dashboard.active_count]).to eq([0, 0])
      end
    end
  end

  it "answers no multiplier when nothing landed on a project" do
    create(:contribution, :confirmed, campaign: create(:campaign, ngo: ngo),
                                      contributor: profile, amount_cents: 40_000)

    expect(dashboard.people_per_base).to be_nil
  end

  # O denominador é o que entrou EM OBRA. R$ 250 comprando 3.750 pessoas dá
  # 15.000 pessoas por ano a cada R$ 1.000 — a estimativa da obra inteira, que
  # é o que se espera de quem financiou um quarto dela.
  it "answers the multiplier over the money that reached a project" do
    funded_project

    expect(dashboard.people_per_base).to eq(15_000)
  end

  it "hands the view the visibility of the context that asked" do
    expect(dashboard.visibility.clearance).to eq(:restricted)
  end
end
