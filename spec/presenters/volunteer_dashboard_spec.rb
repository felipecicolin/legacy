# frozen_string_literal: true

require "rails_helper"

RSpec.describe VolunteerDashboard do
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }
  let(:skill) { create(:skill) }
  let(:ngo) { create(:ngo, :active) }

  def dashboard = described_class.new(profile.reload, Authorization::Context.for(user.reload))

  def skilled_need(base: ngo)
    create(:need, ngo: base, need_kind: :skill, skill: skill)
  end

  describe "#matched_needs" do
    before { create(:profile_skill, profile: profile, skill: skill) }

    it "answers the needs that ask for a skill the person has" do
      wanted = skilled_need

      expect(dashboard.matched_needs).to contain_exactly(wanted)
    end

    it "leaves out a need that asks for a skill the person does not have" do
      create(:need, ngo: ngo, need_kind: :skill, skill: create(:skill))

      expect(dashboard.matched_needs).to be_empty
    end

    # A que ele não pode ver não aparece nem como negada — a mesma regra do
    # oráculo da busca, aplicada ao casamento.
    it "leaves out a need the person cannot reach" do
      skilled_need(base: create(:ngo, :active, country: create(:country, high_risk: true)))

      expect(dashboard.matched_needs).to be_empty
    end
  end

  # Sem habilidade cadastrada não há casamento possível, e a tela precisa dizer
  # isso em vez de mostrar lista vazia, que se lê como "não há o que fazer".
  describe "#skills_registered?" do
    it "is false for someone who never registered one" do
      expect(dashboard).not_to be_skills_registered
    end

    it "is true once there is one" do
      create(:profile_skill, profile: profile, skill: skill)

      expect(dashboard).to be_skills_registered
    end
  end

  describe "#open_needs" do
    it "answers the open needs the person reaches" do
      open_need = create(:need, ngo: ngo)

      expect(dashboard.open_needs(Search::Filters.from({}))).to contain_exactly(open_need)
    end

    it "narrows by the filter it was given" do
      create(:need, ngo: ngo, urgency: :low)

      expect(dashboard.open_needs(Search::Filters.from(urgency: "critical"))).to be_empty
    end

    it "leaves out a need that is already fulfilled" do
      create(:need, ngo: ngo, quantity: 1, fulfilled_quantity: 1, need_status: :fulfilled)

      expect(dashboard.open_needs(Search::Filters.from({}))).to be_empty
    end
  end

  describe "#open_deployments" do
    # O envio não tem nível próprio: listar um para base confidencial contaria
    # que ela existe pelo destino da viagem.
    it "leaves out a deployment to a base the person cannot reach" do
      hidden = create(:ngo, :active, country: create(:country, high_risk: true))
      create(:deployment, ngo: hidden, deployment_status: :open)

      expect(dashboard.open_deployments).to be_empty
    end

    it "answers a deployment to a base the person reaches" do
      going = create(:deployment, ngo: ngo, deployment_status: :open)

      expect(dashboard.open_deployments).to contain_exactly(going)
    end

    it "leaves out a deployment that is not open yet" do
      create(:deployment, ngo: ngo)

      expect(dashboard.open_deployments).to be_empty
    end
  end

  # O que trava a candidatura fica visível ANTES da tentativa.
  describe "the credentials that block a candidacy" do
    it "lists the ones still waiting for verification" do
      pending_one = create(:credential, profile: profile)

      expect(dashboard.pending_credentials).to contain_exactly(pending_one)
    end

    it "leaves out the ones already verified" do
      create(:credential, profile: profile, verification_status: :verified, expires_on: 1.year.from_now.to_date)

      expect(dashboard.pending_credentials).to be_empty
    end

    it "knows when the registration is good" do
      create(:credential, profile: profile, verification_status: :verified, expires_on: 1.year.from_now.to_date)

      expect(dashboard).to be_professional_registration
    end
  end

  describe "#candidacies and #assignments" do
    let(:candidacy) { create(:candidacy, profile: profile, need: create(:need, ngo: ngo)) }
    let!(:assignment) { create(:assignment, candidacy: candidacy, need: candidacy.need) }

    it "answers what the person applied for" do
      expect(dashboard.candidacies).to contain_exactly(candidacy)
    end

    it "answers what they were given" do
      expect(dashboard.assignments).to contain_exactly(assignment)
    end
  end

  describe "#engagements" do
    it "answers the volunteering models the person declared" do
      engagement = create(:volunteer_engagement, profile: profile)

      expect(dashboard.engagements).to contain_exactly(engagement)
    end
  end
end
