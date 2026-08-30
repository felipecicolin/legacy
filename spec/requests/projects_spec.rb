# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Project detail" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password: password) }
  let(:project) { create(:project, title: "Centro comunitário do Vale") }

  def sign_in(as = user)
    post session_path, params: { email_address: as.email_address, password: password }
  end

  before { sign_in }

  it "renders a direct progress and an empty timeline when there are no reports" do
    project.update!(physical_progress: 42)

    get project_path(project.code)

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(project.title, "42%")
      expect(response.body).to include("Avanço informado diretamente, sem relatório aprovado.")
      expect(response.body).to include("Ainda não há relatório aprovado para esta obra.")
    end
  end

  it "shows the newest approved report as the progress provenance" do
    reporter = create(:profile, legal_name: "Ana Ribeiro", display_name: "Ana R.")
    create(:progress_report, :approved, project: project, reported_by: reporter,
                                        physical_progress: 62, reported_on: Date.new(2026, 3, 12),
                                        summary: "<div>Estrutura concluída.</div>")

    get project_path(project.code)

    expect(response.body).to include("62%", "12/03/2026", "Ana R.", "Estrutura concluída.")
  end

  it "paginates twenty reports inside a Turbo Frame" do
    reports = Array.new(20) do |index|
      create(:progress_report, :approved, project: project, reported_on: Date.current - index.days,
                                          summary: "<div>Relatório #{index + 1}</div>")
    end

    get project_path(project.code)
    first_page = response.body

    get project_path(project.code, reports_page: 2), headers: { "Turbo-Frame" => "project-reports" }

    aggregate_failures do
      expect(first_page).to include("Relatório 1", "Relatório 10", "Carregar mais relatórios")
      expect(first_page).to include(%(<turbo-frame id="project-reports">))
      expect(response.body).to include("Relatório 11", "Relatório 20")
      expect(reports.map(&:id)).to eq(reports.sort_by(&:id).map(&:id))
    end
  end

  it "uses the weighted progress when the project has phases" do
    create(:project_phase, project: project, name: "Fundação", weight: 2, physical_progress: 100)
    create(:project_phase, project: project, name: "Cobertura", weight: 1, physical_progress: 0)

    get project_path(project.code)

    expect(response.body).to include("67%", "Total ponderado: 67%.")
  end

  it "falls back to the project progress when phase weights add up to zero" do
    create(:project_phase, project: project, name: "Etapa sem peso", weight: 0, physical_progress: 100)

    get project_path(project.code)

    expect(response.body).to include("0%", "Total ponderado: 0%.", "Peso 0")
  end

  it "renders a visible campaign as the simulated funding source" do
    project = create(:project, ngo: create(:ngo, :active), funding_target_cents: 50_000)
    create(:campaign, ngo: project.ngo, project:, raised_cents: 12_500, goal_cents: 75_000)

    get project_path(project.code)

    expect(response.body).to include("R$ 125,00", "Meta de R$ 750,00")
  end

  it "includes the date and photographer in an accessible report photo caption" do
    reporter = create(:profile, legal_name: "Foto Responsável", display_name: "Foto R.")
    report = create(:progress_report, :approved, project:, reported_by: reporter,
                                                 reported_on: Date.new(2026, 3, 12))
    create(:project_photo, project:, progress_report: report, taken_by: reporter,
                           taken_on: Date.new(2026, 3, 13))

    get project_path(project.code)

    expect(response.body).to include("13/03/2026", "Foto R.")
  end

  it "keeps report and photo queries constant as the timeline grows" do
    one_report = create_reported_project(2)
    get project_path(one_report.code)
    one_query_count = count_queries { get project_path(one_report.code) }
    many_reports = create_reported_project(20)
    get project_path(many_reports.code)
    many_query_count = count_queries { get project_path(many_reports.code) }

    expect(many_query_count).to eq(one_query_count)
  end

  it "renders the team, partially fulfilled needs and an overspent budget line" do
    member = create(:profile, legal_name: "João Silva", display_name: "João S.")
    create(:project_participation, :active, project: project, profile: member, participation_role: :coordinator)
    need = create(:need, ngo: project.ngo, project: project, quantity: 4, fulfilled_quantity: 1)
    budget = create(:budget, project: project)
    line = create(:budget_line, budget: budget, estimated_cents: 1_000)
    create(:expense, project: project, budget_line: line, amount_cents: 1_500)

    get project_path(project.code)

    aggregate_failures do
      expect(response.body).to include("João S.", member.project_participations.first.participation_role_label)
      expect(response.body).to include(need.title, "3 de 4")
      expect(response.body).to include("Linha estourada")
    end
  end

  it "does not expose precise coordinates for an admin viewing a confidential project" do
    admin = create(:user, password: password)
    create(:staff_role, user: admin, staff_level: :admin)
    confidential_ngo = create(:ngo, :active, :located, country: create(:country))
    confidential = create(:project, ngo: confidential_ngo)
    confidential.update!(sensitivity_level: :confidential)
    sign_in(admin)

    get project_path(confidential.code)

    expect(response.body).not_to include("Rua das Palmeiras, 120", "-23.55052", "-46.633308")
  end

  it "answers not found when an anonymous reader cannot reach the project" do
    delete session_path
    get project_path(project.code)

    expect(response).to have_http_status(:not_found)
  end

  private

  def create_reported_project(count)
    record = create(:project)
    count.times do |index|
      report = create(:progress_report, :approved, project: record, reported_on: Date.current - index.days,
                                                   summary: "<div>Relatório #{index}</div>")
      create(:project_photo, project: record, progress_report: report, taken_by: report.reported_by)
    end
    record
  end
end
