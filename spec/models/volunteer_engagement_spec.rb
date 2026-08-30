# frozen_string_literal: true

require "rails_helper"

RSpec.describe VolunteerEngagement do
  describe "the four models of the institutional material" do
    # Dois dos quatro NÃO passam por obra nenhuma, e é por isso que esta camada
    # existe separada de `ProjectParticipation`.
    it "creates every model without a project attached" do
      models = %i[office_fixed project_spot project_permanent corporate].map do |model|
        traits = model == :corporate ? [:in_a_group] : []
        build(:volunteer_engagement, *traits, engagement_model: model).valid?
      end

      expect(models).to all(be(true))
    end

    it "knows which models put someone on a site" do
      answers = %i[office_fixed project_spot project_permanent corporate].map do |model|
        build(:volunteer_engagement, engagement_model: model).works_on_projects?
      end

      expect(answers).to eq([false, true, true, false])
    end
  end

  describe "the group that only the corporate model carries" do
    it "refuses a corporate engagement with no group" do
      expect(build(:volunteer_engagement, engagement_model: :corporate, volunteer_group: nil)).not_to be_valid
    end

    # Nos dois sentidos: grupo num modelo individual é vínculo que ninguém
    # coordena.
    it "refuses an individual engagement that carries a group" do
      engagement = build(:volunteer_engagement, engagement_model: :project_spot,
                                                volunteer_group: create(:volunteer_group))

      expect(engagement).not_to be_valid
    end
  end

  describe "the dates" do
    it "refuses an end before the start" do
      engagement = build(:volunteer_engagement, started_on: Date.current, ended_on: Date.current.yesterday)

      expect(engagement).not_to be_valid
    end

    it "accepts an open ended engagement" do
      expect(build(:volunteer_engagement, ended_on: nil)).to be_valid
    end

    it "refuses an end before the start in the database too" do
      engagement = create(:volunteer_engagement)
      corrupt = "update volunteer_engagements set ended_on = started_on - 1 where id = #{engagement.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /end_after_it_starts/)
    end
  end

  describe "weekly hours" do
    it "refuses a week with more hours than a week has" do
      expect(build(:volunteer_engagement, weekly_hours: 169)).not_to be_valid
    end

    it "accepts an unknown load" do
      expect(build(:volunteer_engagement, weekly_hours: nil)).to be_valid
    end
  end

  # "Divulgação" é engajamento legítimo, não segunda classe: aparece nas mesmas
  # listagens que a obra.
  it "treats communication as an area like any other" do
    outreach = create(:volunteer_engagement, engagement_area: :communication, engagement_status: :active)

    expect(described_class.effective).to include(outreach)
  end

  # Um permanente tem UM engajamento e N participações ao longo do ano — é o
  # que separa as duas camadas.
  describe "a permanent volunteer" do
    let(:profile) { create(:profile) }

    before do
      create(:volunteer_engagement, profile: profile, engagement_model: :project_permanent)
      create_list(:project, 3).each { |project| create(:project_participation, profile: profile, project: project) }
    end

    # UM engajamento e N participações ao longo do ano — é o que separa as duas
    # camadas, e fundi-las apagaria o caso.
    it "keeps one engagement alongside participations in several projects" do
      expect(profile.project_participations.count).to eq(3)
    end
  end

  describe "labels" do
    subject(:engagement) { build(:volunteer_engagement, :at_the_office) }

    it "translates model, area and status to pt-BR" do
      aggregate_failures do
        expect(engagement.engagement_model_label).to eq("Escritório fixo")
        expect(engagement.engagement_area_label).to eq("Escritório")
        expect(engagement.engagement_status_label).to eq("Inscrito")
      end
    end
  end
end
