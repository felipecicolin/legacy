# frozen_string_literal: true

require "rails_helper"

RSpec.describe SiteSurvey do
  let(:project) { create(:project) }

  describe "the findings that the submission requires" do
    it "accepts a draft with nothing written yet" do
      expect(build(:site_survey, project: project)).to be_valid
    end

    it "refuses a submission with no findings" do
      expect(build(:site_survey, project: project, status: :submitted)).not_to be_valid
    end

    # `<div><br></div>` é o que o Trix envia quando ninguém digitou nada, e
    # `body.present?` acha que isso é conteúdo.
    it "refuses a submission whose findings are only what an empty Trix sends" do
      survey = build(:site_survey, project: project, status: :submitted, findings: "<div><br></div>")

      expect(survey).not_to be_valid
    end

    it "accepts a submission with findings" do
      expect(build(:site_survey, :submitted, project: project)).to be_valid
    end
  end

  describe "the survey date" do
    it "refuses a survey dated in the future" do
      expect(build(:site_survey, project: project, surveyed_on: Date.current.tomorrow)).not_to be_valid
    end

    it "accepts a survey dated today" do
      expect(build(:site_survey, project: project, surveyed_on: Date.current)).to be_valid
    end
  end

  describe "the estimated cost" do
    it "refuses a negative estimate and accepts an unknown one" do
      aggregate_failures do
        expect(build(:site_survey, project: project, estimated_cost_cents: -1)).not_to be_valid
        expect(build(:site_survey, project: project, estimated_cost_cents: nil)).to be_valid
      end
    end

    it "refuses a negative estimate in the database too" do
      survey = create(:site_survey, project: project)
      corrupt = "update site_surveys set estimated_cost_cents = -1 where id = #{survey.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /estimated_cost/)
    end

    it "refuses a currency that is not a three letter code" do
      expect(build(:site_survey, project: project, currency: "REAIS")).not_to be_valid
    end
  end

  # A obra entra em levantamento ANTES de alguém visitar: zero levantamentos é
  # estado legítimo, e é o que a issue pede que fique escrito.
  it "lets a project sit in surveying with zero, one or three surveys" do
    surveyed = ->(number) { create(:project).tap { |record| create_list(:site_survey, number, project: record) } }

    expect([0, 1, 3].map { |number| surveyed.call(number).site_surveys.count }).to eq([0, 1, 3])
  end

  it "labels the state in pt-BR" do
    expect(build(:site_survey, :submitted, project: project).status_label).to eq("Enviado")
  end
end
