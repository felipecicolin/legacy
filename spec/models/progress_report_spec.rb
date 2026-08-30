# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressReport do
  let(:project) { create(:project) }

  describe "the summary that the submission requires" do
    it "accepts a draft with nothing written yet" do
      expect(build(:progress_report, project: project)).to be_valid
    end

    it "refuses a submission with no summary" do
      expect(build(:progress_report, project: project, status: :submitted)).not_to be_valid
    end

    # `<div><br></div>` é o que o Trix envia quando ninguém digitou nada, e
    # `body.present?` acha que isso é conteúdo. Ver docs/action-text.md.
    it "refuses a submission whose summary is only what an empty Trix sends" do
      report = build(:progress_report, project: project, status: :submitted, summary: "<div><br></div>")

      expect(report).not_to be_valid
    end

    it "accepts a submission with a summary" do
      expect(build(:progress_report, :submitted, project: project)).to be_valid
    end
  end

  describe "progress" do
    it "refuses a value outside the range" do
      values = [-1, 101].map { |value| build(:progress_report, project: project, physical_progress: value).valid? }

      expect(values).to eq([false, false])
    end

    # A validação pega o formulário; o CHECK pega seed, console e SQL cru — e é
    # o cache da obra, que ordena as listagens, que um valor fora de faixa
    # corrompe.
    it "refuses a value outside the range in the database too" do
      report = create(:progress_report, project: project)
      corrupt = "update progress_reports set physical_progress = 140 where id = #{report.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /physical_progress/)
    end

    # Obra tem retrabalho. Bloquear a regressão obrigaria a mentir no
    # relatório; o que ela exige é a explicação, que a submissão já exige.
    it "accepts a report that reports less progress than the one before it" do
      create(:progress_report, :approved, project: project, physical_progress: 62)
      regression = build(:progress_report, :submitted, project: project, physical_progress: 55)

      expect(regression).to be_valid
    end

    it "refuses a negative headcount and accepts an unknown one" do
      aggregate_failures do
        expect(build(:progress_report, project: project, workers_on_site: -1)).not_to be_valid
        expect(build(:progress_report, project: project, workers_on_site: nil)).to be_valid
      end
    end
  end

  describe "the date" do
    it "refuses a report from the future" do
      expect(build(:progress_report, project: project, reported_on: Date.current.tomorrow)).not_to be_valid
    end

    it "accepts a report from today" do
      expect(build(:progress_report, project: project, reported_on: Date.current)).to be_valid
    end
  end

  describe "an approved report" do
    let(:report) { create(:progress_report, :approved, project: project) }

    # Correção é relatório novo. Trilha reescrita não é trilha.
    it "refuses to be edited" do
      expect(report.update(physical_progress: 70)).to be(false)
    end

    it "raises when the edit is forced past the validations" do
      report.physical_progress = 70

      expect { report.save(validate: false) }.to raise_error(described_class::ApprovedReportIsImmutable)
    end

    # A aprovação É um update: ela grava `approved_by` e `approved_at`. Uma
    # guarda que perguntasse `approved?` em vez de `status_was` bloquearia a
    # própria aprovação.
    it "does not block its own approval" do
      draft = create(:progress_report, :written, project: project)

      expect(draft.update(status: :approved)).to be(true)
    end
  end

  describe "the project progress cache" do
    it "moves only when the report is approved" do
      report = create(:progress_report, :written, project: project, physical_progress: 62)

      expect { report.update!(status: :submitted) }.not_to(change { project.reload.physical_progress })
    end

    it "moves when a report is approved" do
      report = create(:progress_report, :written, project: project, physical_progress: 62)

      expect { report.update!(status: :approved) }.to change { project.reload.physical_progress }.from(0).to(62)
    end

    it "follows the most recent approved report, not the highest" do
      create(:progress_report, :approved, project: project, physical_progress: 62,
                                          reported_on: Date.current.yesterday)
      create(:progress_report, :approved, project: project, physical_progress: 55)

      expect(project.reload.physical_progress).to eq(55)
    end
  end

  describe ".latest_per_project" do
    it "answers one approved report per project" do
      create(:progress_report, :approved, project: project, physical_progress: 62,
                                          reported_on: Date.current.yesterday)
      newest = create(:progress_report, :approved, project: project, physical_progress: 70)

      expect(described_class.latest_per_project.map(&:id)).to eq([newest.id])
    end

    it "leaves out a project whose reports are not approved" do
      create(:progress_report, :submitted, project: project)

      expect(described_class.latest_per_project).to be_empty
    end

    # Dois relatórios no mesmo dia: o desempate por `id` é o que faz a resposta
    # ser determinística em vez de depender da ordem física das linhas.
    it "breaks a same day tie by id, deterministically" do
      create(:progress_report, :approved, project: project, physical_progress: 40)
      newest = create(:progress_report, :approved, project: project, physical_progress: 41)

      expect(described_class.latest_per_project.first.id).to eq(newest.id)
    end

    # O escopo existe para o card de 50 obras mostrar percentual E data sem
    # N+1. O que prova ausência de N+1 não é um número absoluto, e sim que ele
    # NÃO CRESCE: a mesma medição com uma obra e com cinco.
    it "costs the same number of queries no matter how many projects there are" do
      report_for = ->(record) { create(:progress_report, :approved, project: record) }
      report_for.call(project)
      with_one = count_queries { described_class.latest_per_project.to_a }
      create_list(:project, 4).each(&report_for)

      expect(count_queries { described_class.latest_per_project.to_a }).to eq(with_one)
    end
  end

  it "labels the state in pt-BR" do
    expect(build(:progress_report, :approved, project: project).status_label).to eq("Aprovado")
  end
end
