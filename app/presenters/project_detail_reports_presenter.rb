# frozen_string_literal: true

class ProjectDetailReportsPresenter
  REPORTS_PER_PAGE = 10

  def initialize(project, visibility, page: nil)
    @project = project
    @visibility = visibility
    page_number = page.to_i
    @reports_page = page_number.positive? ? page_number : 1
  end

  attr_reader :reports_page

  def progress_report = latest_report

  def reports = report_rows.first(REPORTS_PER_PAGE)
  def more_reports? = report_rows.length > REPORTS_PER_PAGE
  def next_reports_page = reports_page + 1

  def report_author(report, role_label:)
    ProfilePresenter.new(report.reported_by, role_label:, subject: @project).name_for(@visibility)
  end

  # A série do avanço no tempo, em ordem crescente — o oposto da listagem, que
  # é decrescente porque lá o mais recente é o que interessa. Um gráfico lido
  # da direita para a esquerda não se lê.
  def progress_series
    @project.progress_reports.approved.order(:reported_on)
            .pluck(:reported_on, :physical_progress)
            .map { |on, percentage| { x: on.iso8601, y: percentage } }
  end

  def photo_caption(photo)
    [I18n.l(photo.taken_on), photo.credit_for(@visibility)].compact.join(" · ")
  end

  private

  def latest_report
    @latest_report ||= @project.progress_reports.approved.latest_first.includes(:reported_by).first
  end

  def report_rows
    @report_rows ||= @project.progress_reports.approved.latest_first
                             .offset((reports_page - 1) * REPORTS_PER_PAGE)
                             .limit(REPORTS_PER_PAGE + 1)
                             .includes(:reported_by, :rich_text_summary, :rich_text_blockers,
                                       project_photos: [:taken_by, { image_attachment: :blob }]).to_a
  end
end
