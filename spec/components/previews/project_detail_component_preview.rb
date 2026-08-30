# frozen_string_literal: true

class ProjectDetailComponentPreview < ViewComponent::Preview
  Stage = Data.define(:name, :weight, :physical_progress)

  class Presenter
    def title = "Centro comunitário do Vale"
    def code = "OB-0247"
    def status = "in_progress"
    def location = "Vale do Paraíba · Brasil"
    def physical_progress = 62
    def progress_report = nil
    def funding_value = 62_000
    def funding_target = 100_000
    def funding_currency = "BRL"
    def stages = [Stage.new(name: "Estrutura", weight: 2, physical_progress: 80)]
    alias phases stages
    def phase_contribution(stage) = stage.weight * stage.physical_progress / 3.0
    def reports = []
    def more_reports? = false
    def next_reports_page = 2
    def team_members = []
    def needs = []
    def budget_rows = []
    def budget_total_cents = 0
  end

  def default
    render(ProjectDetailComponent.new(presenter: Presenter.new))
  end
end
