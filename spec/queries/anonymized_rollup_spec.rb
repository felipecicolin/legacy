# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnonymizedRollup do
  let(:visibility) { Visibility::Context.anonymous }
  let(:base) { mission_base_with_region }

  it "suppresses a region with fewer than 3 hidden projects" do
    create_list(:project, 2, mission_base: base)

    expect(described_class.new(visibility).by_region).to be_empty
  end

  it "publishes a region with 3 or more hidden projects, with count and average progress" do
    create_hidden_projects(base, progresses: [0, 30, 60])

    row = described_class.new(visibility).by_region.first

    expect(row).to have_attributes(project_count: 3, average_physical_progress: 30)
  end

  it "never exposes an individual project's or base's identifying data" do
    projects = create_hidden_projects(base, progresses: [0, 30, 60])

    payload = described_class.new(visibility).by_region.to_s

    expect(payload).not_to include(base.name, *projects.map(&:code))
  end

  it "runs a constant number of queries regardless of how many regions are hidden" do
    rollup = described_class.new(visibility)
    first_measurement = query_count_for(2, rollup)
    second_measurement = query_count_for(6, rollup)

    expect(second_measurement).to eq(first_measurement)
  end

  def create_hidden_projects(base, progresses:)
    progresses.map { |value| create(:project, mission_base: base, physical_progress: value) }
  end

  def seed_hidden_regions(count)
    count.times { create_hidden_projects(mission_base_with_region, progresses: [0, 30, 60]) }
  end

  def query_count_for(region_count, rollup)
    seed_hidden_regions(region_count)
    count_queries { rollup.by_region }
  end

  # `MissionBase` valida que sua região pertence ao mesmo país da base — a
  # fábrica de cada uma gera o país sozinha, então as duas precisam ser
  # criadas com o país em comum, não uma independente da outra.
  def mission_base_with_region
    country = create(:country)
    create(:mission_base, country: country, region: create(:region, country: country))
  end
end
