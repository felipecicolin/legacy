# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Filters do
  let(:country) { create(:country) }
  let(:mission_base) { create(:mission_base, :active, country: country) }

  def filtered_projects(**params)
    described_class.from(params).apply_to_projects(Project.all)
  end

  def filtered_bases(**params)
    described_class.from(params).apply_to_mission_bases(MissionBase.all)
  end

  # A URL é escrita por gente. Um `?status=demolida` colado errado devolve a
  # lista sem o filtro — não uma exceção, e não uma lista vazia que se lê como
  # "não existe nada".
  describe "a value that is not in the vocabulary" do
    it "ignores an unknown project status" do
      create(:project, mission_base: mission_base)

      expect(filtered_projects(status: "demolida").count).to eq(1)
    end

    it "ignores an unknown base kind" do
      mission_base

      expect(filtered_bases(base_kind: "castelo").count).to eq(1)
    end

    it "reads an unparsable progress as no floor at all" do
      create(:project, mission_base: mission_base)

      expect(filtered_projects(min_progress: "muito").count).to eq(1)
    end
  end

  describe "the filters that do apply" do
    it "keeps only the projects in the status asked for" do
      create(:project, mission_base: mission_base)
      paused = create(:project, mission_base: mission_base)
      paused.update_column(:status, Project.statuses.fetch("paused"))

      expect(filtered_projects(status: "paused")).to contain_exactly(paused)
    end

    it "keeps only the projects at or above the progress floor" do
      create(:project, mission_base: mission_base)
      advanced = create(:project, mission_base: mission_base)
      advanced.update_column(:physical_progress, 60)

      expect(filtered_projects(min_progress: "50")).to contain_exactly(advanced)
    end

    it "keeps only the projects of bases in the country asked for" do
      wanted = create(:project, mission_base: mission_base)
      create(:project)

      expect(filtered_projects(country_id: country.id)).to contain_exactly(wanted)
    end

    it "keeps only the bases of the kind asked for" do
      school = create(:mission_base, base_kind: :school)
      mission_base

      expect(filtered_bases(base_kind: "school")).to contain_exactly(school)
    end

    it "keeps only the bases in the country asked for" do
      create(:mission_base)

      expect(filtered_bases(country_id: country.id)).to contain_exactly(mission_base)
    end
  end

  # A mesma gramática de filtro serve a busca e o painel do voluntário: são os
  # mesmos nomes na mesma query string, e duas gramáticas divergiriam.
  describe "the needs of the volunteer view" do
    def filtered_needs(**params)
      described_class.from(params).apply_to_needs(Need.all)
    end

    it "keeps only the needs of the kind asked for" do
      wanted = create(:need, mission_base: mission_base, need_kind: :team)
      create(:need, mission_base: mission_base, need_kind: :material)

      expect(filtered_needs(status: "team")).to contain_exactly(wanted)
    end

    it "keeps only the needs of the urgency asked for" do
      wanted = create(:need, mission_base: mission_base, urgency: :critical)
      create(:need, mission_base: mission_base, urgency: :low)

      expect(filtered_needs(urgency: "critical")).to contain_exactly(wanted)
    end

    it "keeps only the needs whose base is in the country asked for" do
      wanted = create(:need, mission_base: mission_base)
      create(:need)

      expect(filtered_needs(country_id: country.id)).to contain_exactly(wanted)
    end

    it "ignores a kind that is not in the vocabulary" do
      create(:need, mission_base: mission_base)

      expect(filtered_needs(status: "vontade").count).to eq(1)
    end
  end

  describe "#any?" do
    it "is false when nothing was set" do
      expect(described_class.from({})).not_to be_any
    end

    it "is true as soon as one filter arrives" do
      expect(described_class.from(status: "paused")).to be_any
    end

    it "reads a blank value as absent" do
      expect(described_class.from(status: "")).not_to be_any
    end
  end
end
