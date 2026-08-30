# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deployment do
  let(:mission_base) { create(:mission_base) }

  describe "where a deployment goes" do
    # Envio para levantar uma base ainda sem obra aberta é o caso normal, não a
    # exceção — a mesma separação que `Need` faz.
    it "accepts a deployment to a base with no project" do
      expect(build(:deployment, mission_base: mission_base, project: nil)).to be_valid
    end

    it "accepts a deployment to a project of its own base" do
      project = create(:project, mission_base: mission_base)

      expect(build(:deployment, mission_base: mission_base, project: project)).to be_valid
    end

    it "refuses a project that belongs to another base" do
      expect(build(:deployment, mission_base: mission_base, project: create(:project))).not_to be_valid
    end
  end

  describe "the travel dates" do
    it "refuses a return before the departure" do
      deployment = build(:deployment, mission_base: mission_base,
                                      departs_on: Date.current, returns_on: Date.current.yesterday)

      expect(deployment).not_to be_valid
    end

    it "refuses a return before the departure in the database too" do
      deployment = create(:deployment, mission_base: mission_base)
      corrupt = "update deployments set returns_on = departs_on - 1 where id = #{deployment.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /returns_after_it_departs/)
    end
  end

  describe "capacity" do
    # Capacidade é do avião e da casa, não uma sugestão: passar dela é
    # descobrir na véspera que falta cama para duas pessoas.
    it "refuses more confirmed people than seats" do
      deployment = create(:deployment, mission_base: mission_base, capacity: 1)
      create_list(:profile, 2).each do |profile|
        create(:deployment_member, deployment: deployment, profile: profile, member_status: :confirmed)
      end

      expect(deployment.reload).not_to be_valid
    end

    # Convite não ocupa vaga — é convite, não confirmação.
    it "does not count an invitation against the seats" do
      deployment = create(:deployment, mission_base: mission_base, capacity: 1)
      create(:deployment_member, deployment: deployment)

      expect(deployment.reload.seats_left).to eq(1)
    end

    # Quem já foi e voltou continua tendo ocupado a vaga: a contagem responde
    # "quantos lugares foram comprometidos".
    it "keeps counting someone who already returned" do
      deployment = create(:deployment, mission_base: mission_base, capacity: 2)
      create(:deployment_member, deployment: deployment, member_status: :returned)

      expect(deployment.reload.seats_left).to eq(1)
    end

    it "answers nothing when the capacity was never declared" do
      expect(create(:deployment, mission_base: mission_base, capacity: nil).seats_left).to be_nil
    end

    it "refuses a deployment with room for nobody" do
      expect(build(:deployment, mission_base: mission_base, capacity: 0)).not_to be_valid
    end
  end

  describe "the members" do
    it "keeps one row per person on a deployment" do
      deployment = create(:deployment, mission_base: mission_base)
      profile = create(:profile)
      create(:deployment_member, deployment: deployment, profile: profile)

      expect(build(:deployment_member, deployment: deployment, profile: profile)).not_to be_valid
    end

    it "translates role and status to pt-BR" do
      member = build(:deployment_member, member_role: :medical, member_status: :travelling)

      aggregate_failures do
        expect(member.member_role_label).to eq("Saúde")
        expect(member.member_status_label).to eq("Em viagem")
      end
    end
  end

  describe ".upcoming" do
    it "lists the deployments still to come, closest first" do
      later = create(:deployment, mission_base: mission_base, departs_on: 3.months.from_now.to_date,
                                  returns_on: 4.months.from_now.to_date)
      sooner = create(:deployment, mission_base: mission_base, departs_on: 1.week.from_now.to_date,
                                   returns_on: 2.weeks.from_now.to_date)

      expect(described_class.upcoming).to eq([sooner, later])
    end

    it "leaves out a deployment that already departed" do
      create(:deployment, mission_base: mission_base, departs_on: 1.week.ago.to_date,
                          returns_on: Date.current)

      expect(described_class.upcoming).to be_empty
    end
  end

  it "refuses a negative cost and a currency that is not a three letter code" do
    aggregate_failures do
      expect(build(:deployment, mission_base: mission_base, cost_per_person_cents: -1)).not_to be_valid
      expect(build(:deployment, mission_base: mission_base, currency: "REAIS")).not_to be_valid
    end
  end

  it "translates the status to pt-BR and interpolates as its name" do
    deployment = build(:deployment, mission_base: mission_base, name: "Envio de campo", deployment_status: :travelling)

    aggregate_failures do
      expect(deployment.deployment_status_label).to eq("Em viagem")
      expect(deployment.to_s).to eq("Envio de campo")
    end
  end
end
