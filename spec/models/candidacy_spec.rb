# frozen_string_literal: true

require "rails_helper"

RSpec.describe Candidacy do
  let(:need) { create(:need) }

  describe "exactly one candidate" do
    it "accepts an individual candidacy" do
      expect(build(:candidacy, need: need)).to be_valid
    end

    it "accepts a group candidacy" do
      expect(build(:candidacy, :from_a_group, need: need)).to be_valid
    end

    it "refuses a candidacy with both" do
      candidacy = build(:candidacy, need: need, volunteer_group: create(:volunteer_group))

      expect(candidacy).not_to be_valid
    end

    it "refuses a candidacy with neither" do
      expect(build(:candidacy, need: need, profile: nil)).not_to be_valid
    end

    # A validação pega o formulário; o CHECK pega seed, console e SQL cru.
    it "refuses a candidacy with both in the database too" do
      candidacy = create(:candidacy, need: need)
      group = create(:volunteer_group)
      corrupt = "update candidacies set volunteer_group_id = #{group.id} where id = #{candidacy.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /exactly_one_candidate/)
    end
  end

  describe "the partial unique indexes" do
    it "keeps one candidacy per person per need" do
      profile = create(:profile)
      create(:candidacy, need: need, profile: profile)

      expect(build(:candidacy, need: need, profile: profile)).not_to be_valid
    end

    # O índice é PARCIAL: sem o `where`, duas candidaturas de grupo colidiriam
    # pelo `profile_id` nulo das duas.
    it "lets two different groups apply to the same need" do
      create(:candidacy, :from_a_group, need: need)

      expect(build(:candidacy, :from_a_group, need: need)).to be_valid
    end

    it "keeps one candidacy per group per need" do
      group = create(:volunteer_group)
      create(:candidacy, need: need, profile: nil, volunteer_group: group)

      expect(build(:candidacy, need: need, profile: nil, volunteer_group: group)).not_to be_valid
    end
  end

  describe "a need that is no longer taking anyone" do
    it "refuses a candidacy to a fulfilled need" do
      full = create(:need, quantity: 1)
      full.fulfill(source: create(:assignment), quantity: 1)

      expect(build(:candidacy, need: full.reload)).not_to be_valid
    end

    it "accepts a candidacy to a need that is only partly fulfilled" do
      partial = create(:need, quantity: 3)
      partial.fulfill(source: create(:assignment), quantity: 1)

      expect(build(:candidacy, need: partial.reload)).to be_valid
    end
  end

  describe "the professional registration gate" do
    let(:gated) { create(:need, :skilled, requires_professional_registration: true) }

    it "refuses a candidate with no verified credential" do
      expect(build(:candidacy, need: gated)).not_to be_valid
    end

    it "accepts a candidate whose credential is verified and current" do
      profile = create(:profile)
      create(:credential, profile: profile, verification_status: :verified, expires_on: 1.year.from_now.to_date)

      expect(build(:candidacy, need: gated, profile: profile)).to be_valid
    end

    # O grupo não é gateado: quem responde pelo registro é a pessoa alocada, e
    # a alocação é individual.
    it "does not gate a group candidacy" do
      expect(build(:candidacy, :from_a_group, need: gated)).to be_valid
    end

    it "does not gate a need that asks for no registration" do
      expect(build(:candidacy, need: need)).to be_valid
    end
  end

  describe "the decision stamp" do
    it "stamps the moment a candidacy is decided" do
      candidacy = create(:candidacy, need: need)

      expect { candidacy.update!(candidacy_status: :approved) }.to change { candidacy.decided_at.present? }.to(true)
    end

    it "leaves the stamp empty while the candidacy is still moving" do
      candidacy = create(:candidacy, need: need)
      candidacy.update!(candidacy_status: :screening)

      expect(candidacy.decided_at).to be_nil
    end
  end

  # Recandidatar REABRE o mesmo registro: a história fica num lugar só em vez
  # de virar duas linhas que discordam.
  describe "#reapply" do
    it "reopens a withdrawn candidacy instead of creating a second one" do
      candidacy = create(:candidacy, need: need, candidacy_status: :withdrawn)

      expect { candidacy.reapply }.to change(candidacy, :candidacy_status).to("submitted")
    end

    it "clears the decision it carried" do
      candidacy = create(:candidacy, need: need)
      candidacy.update!(candidacy_status: :rejected, rejection_reason: :no_availability)

      expect { candidacy.reapply }.to change(candidacy, :rejection_reason).to(nil)
    end
  end

  describe "labels" do
    it "translates status and rejection reason to pt-BR" do
      candidacy = build(:candidacy, need: need, candidacy_status: :rejected, rejection_reason: :missing_credential)

      aggregate_failures do
        expect(candidacy.candidacy_status_label).to eq("Recusada")
        expect(candidacy.rejection_reason_label).to eq("Sem registro profissional verificado")
      end
    end

    it "answers no reason when none was recorded" do
      expect(build(:candidacy, need: need).rejection_reason_label).to be_nil
    end

    it "answers whichever candidate it carries" do
      group = create(:volunteer_group)

      expect(build(:candidacy, need: need, profile: nil, volunteer_group: group).candidate).to eq(group)
    end
  end
end
