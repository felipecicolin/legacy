# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectParticipation do
  let(:project) { create(:project) }
  let(:profile) { create(:profile) }

  describe "the unique index" do
    # A mesma pessoa É `technical_lead` e `local_host` na mesma obra. Deixar
    # `role` fora do índice proibiria um caso real.
    it "lets the same person hold two roles on the same project" do
      create(:project_participation, project: project, profile: profile, participation_role: :technical_lead)
      second = build(:project_participation, project: project, profile: profile, participation_role: :local_host)

      expect(second).to be_valid
    end

    it "refuses the same person in the same role on the same project" do
      create(:project_participation, project: project, profile: profile, participation_role: :volunteer)
      repeated = build(:project_participation, project: project, profile: profile, participation_role: :volunteer)

      expect(repeated).not_to be_valid
    end
  end

  describe "the dates" do
    it "refuses an end before the start" do
      participation = build(:project_participation, project: project,
                                                    started_on: Date.current, ended_on: Date.current.yesterday)

      expect(participation).not_to be_valid
    end

    it "accepts an open ended participation" do
      expect(build(:project_participation, project: project, ended_on: nil)).to be_valid
    end

    it "refuses an end before the start in the database too" do
      participation = create(:project_participation, project: project)
      corrupt = "update project_participations set ended_on = started_on - 1 where id = #{participation.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /ends_after_it_starts/)
    end
  end

  describe "#may_report?" do
    # Convite pendente não concede nada — mesma decisão do `accepted_at` de
    # `Membership`. E nem todo vínculo ativo reporta: relatório é prestação de
    # contas, e a assinatura tem de ter dono.
    it "answers only for the roles that answer for the work, and only once accepted" do
      answers = %i[coordinator technical_lead volunteer local_host observer].map do |role|
        build(:project_participation, :active, project: project, participation_role: role).may_report?
      end

      expect(answers).to eq([true, true, false, false, false])
    end

    it "refuses someone who was only invited" do
      expect(build(:project_participation, project: project, participation_role: :coordinator).may_report?).to be(false)
    end
  end

  describe "labels" do
    it "translates role and status to pt-BR" do
      participation = build(:project_participation, :coordinator, project: project)

      aggregate_failures do
        expect(participation.participation_role_label).to eq("Coordenação")
        expect(participation.participation_status_label).to eq("Ativa")
      end
    end
  end
end
