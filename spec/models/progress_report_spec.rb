# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressReport do
  subject(:report) { build(:progress_report) }

  let(:first_report) do
    value = create(:progress_report, project: report.project,
                                     reported_on: 1.day.ago.to_date, physical_progress: 20)
    approve_report(value, "Primeiro")
  end
  let(:second_report) do
    value = create(:progress_report, project: report.project,
                                     reported_on: Date.current, physical_progress: 80)
    approve_report(value, "Segundo")
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:reported_by).class_name("Profile") }
  it { is_expected.to belong_to(:approved_by).class_name("Profile").optional }
  it { is_expected.to have_rich_text(:summary) }
  it { is_expected.to have_rich_text(:blockers) }
  it { is_expected.to have_many_attached(:photos) }

  it "allows a draft" do
    expect(report).to be_valid
  end

  it "requires a summary to submit" do
    report.status = :submitted

    expect(report).not_to be_valid
  end

  it "rejects an empty rich text summary" do
    report.status = :submitted
    report.summary = "<div><br></div>"

    expect(report).not_to be_valid
  end

  it "submits a report with a summary" do
    report.summary = "<div>Avanço medido</div>"

    expect { report.submit! }.not_to raise_error
  end

  it "returns false when a report cannot be submitted" do
    expect(report.submit).to be(false)
  end

  it "requires an explanation when progress regresses" do
    approve_report(create(:progress_report, project: report.project, physical_progress: 62), "Anterior")
    prepare_approved_report(report, 55)

    expect(report).not_to be_valid
  end

  it "does not require an explanation when progress advances" do
    approve_report(create(:progress_report, project: report.project, physical_progress: 62), "Anterior")
    prepare_approved_report(report, 70)
    report.summary = "<div>Avanço</div>"

    expect(report).to be_valid
  end

  it "handles a report without a project" do
    value = build(:progress_report, project: nil, status: :approved, approved_by: create(:profile))

    expect(value).not_to be_valid
  end

  it "scrubs photos assigned through the collection writer" do
    report.save!
    report.photos.attach(GeotaggedPhoto.upload(filename: "relatorio.jpg"))
    report.photos.attach(report.photos_blobs.first)

    expect(report.photos_blobs).to have_attributes(size: 1)
  end

  it "rejects future report dates and negative progress" do
    expect(build(:progress_report, reported_on: 1.day.from_now.to_date)).not_to be_valid
    expect(build(:progress_report, physical_progress: -1)).not_to be_valid
  end

  it "rejects progress outside the database range" do
    expect(build(:progress_report, physical_progress: 101)).not_to be_valid
  end

  it "enforces the database progress check" do
    expect do
      ApplicationRecord.connection.execute(invalid_progress_sql)
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "approves, updates the project cache and then becomes immutable" do
    report.summary = "<div>Resumo</div>"
    report.approve!(approver: create(:profile))

    expect(report).to be_approved
    expect(report.project.reload.physical_progress).to eq(50)
    expect { report.update!(workers_on_site: 2) }.to raise_error(ProgressReport::Immutable)
  end

  it "returns false when approval fails validation" do
    expect(report.approve(approver: create(:profile))).to be(false)
  end

  it "allows a progress regression only with an explanation" do
    approve_report(create(:progress_report, project: report.project, physical_progress: 62), "Primeiro")
    report.physical_progress = 55
    report.summary = "<div>Retrabalho necessário</div>"

    expect { report.approve!(approver: create(:profile)) }.not_to raise_error
  end

  it "chooses the latest approved report by date and id" do
    reports = [first_report, second_report]
    latest = described_class.latest_per_project.where(project_id: report.project.id).to_a

    expect(report.project.reload.latest_progress_report).to eq(reports.last)
    expect(latest).to contain_exactly(reports.last)
  end

  it "uses its project as the visibility subject" do
    expect(report.visibility_subject).to eq(report.project)
  end

  def approve_report(value, text)
    value.summary = "<div>#{text}</div>"
    value.approve!(approver: create(:profile))
    value
  end

  def prepare_approved_report(value, progress)
    value.assign_attributes(status: :approved, approved_by: create(:profile),
                            approved_at: Time.current, physical_progress: progress)
  end

  def invalid_progress_sql
    <<~SQL.squish
      insert into progress_reports
        (project_id, reported_by_id, reported_on, physical_progress, status, created_at, updated_at)
      values (#{report.project_id || 0}, #{report.reported_by_id || 0}, current_date, 101, 0, now(), now())
    SQL
  end
end
