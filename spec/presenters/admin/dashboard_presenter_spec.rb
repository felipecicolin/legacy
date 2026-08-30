# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DashboardPresenter do
  let(:visibility) { Visibility::Context.new(clearance: :confidential) }
  let(:mission_base) { create(:mission_base) }

  describe "#tiles" do
    it "returns four tiles, with the funding one pending" do
      tiles = described_class.new(visibility).tiles

      expect(tiles.map(&:pending)).to eq([false, false, false, true])
      expect(tiles.last).to have_attributes(value: nil, icon: "chart-bar")
    end

    it "counts active work, excluding completed projects" do
      create(:project, mission_base: mission_base, status: :in_progress)
      create(:project, mission_base: mission_base, status: :completed)

      expect(described_class.new(visibility).tiles.first.value).to eq("1")
    end

    it "sums people served across mission bases" do
      create(:mission_base, people_served: 40)
      create(:mission_base, people_served: 60)

      expect(described_class.new(visibility).tiles.second.value).to eq("100")
    end

    it "counts only effective (active) volunteer engagements" do
      create(:volunteer_engagement)
      create(:volunteer_engagement, engagement_status: :screening)

      expect(described_class.new(visibility).tiles.third.value).to eq("0")
    end
  end

  describe "#alerts" do
    it "is empty with no urgent or paused work and no critical need" do
      expect(described_class.new(visibility).alerts).to be_empty
    end

    it "flags urgent projects, with a Portuguese count" do
      create(:project, mission_base: mission_base, status: :urgent)

      alert = described_class.new(visibility).alerts.first

      expect(alert).to have_attributes(severity: "destructive", title: "1 obra urgente")
    end

    it "flags a project paused for more than 15 days, not a recently paused one" do
      create(:project, mission_base: mission_base, status: :paused, updated_at: 20.days.ago)
      create(:project, mission_base: mission_base, status: :paused, updated_at: 1.day.ago)

      alert = described_class.new(visibility).alerts.find { |a| a.severity == "warning" && a.href == "/obras" }

      expect(alert.title).to eq("1 obra parada há mais de 15 dias")
    end

    it "flags a critical need due soon, not a low-urgency one" do
      create(:need, mission_base: mission_base, urgency: :critical, needed_by: 3.days.from_now)
      create(:need, mission_base: mission_base, urgency: :low, needed_by: 3.days.from_now)

      alert = described_class.new(visibility).alerts.find { |a| a.href == "/necessidades" }

      expect(alert.title).to eq("1 necessidade crítica vencendo")
    end

    it "does not alert on work a lower-clearance viewer cannot see" do
      create(:project, mission_base: mission_base, status: :urgent, sensitivity_level: :confidential)
      restricted = Visibility::Context.new(clearance: :restricted)

      expect(described_class.new(restricted).alerts).to be_empty
    end
  end

  describe "#active_projects" do
    it "excludes completed work and orders by urgency" do
      create(:project, mission_base: mission_base, status: :completed)
      surveying = create(:project, mission_base: mission_base, status: :surveying)
      urgent = create(:project, mission_base: mission_base, status: :urgent)

      expect(described_class.new(visibility).active_projects).to eq([urgent, surveying])
    end
  end

  describe "#recent_activity" do
    it "lists only approved reports, most recent first" do
      project = create(:project, mission_base: mission_base)
      create(:progress_report, :approved, project: project, reported_on: 2.days.ago)
      recent = create(:progress_report, :approved, project: project, reported_on: 1.day.ago)
      create(:progress_report, :submitted, project: project)

      expect(described_class.new(visibility).recent_activity.first).to eq(recent)
    end
  end

  describe "#country_rollup" do
    it "delegates to AnonymizedRollup" do
      rollup = instance_double(AnonymizedRollup, by_region: [])
      allow(AnonymizedRollup).to receive(:new).with(visibility).and_return(rollup)

      expect(described_class.new(visibility).country_rollup).to eq([])
    end
  end
end
