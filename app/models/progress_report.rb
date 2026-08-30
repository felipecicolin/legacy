# frozen_string_literal: true

# Avanço como log de eventos, não coluna mutável.
#
# O design system pede "62%" com foto e legenda de data e responsável — isso é
# um relatório, não um número. Uma coluna mutável dá o número sem procedência:
# quem disse 62%, quando, e com que foto. E é o registro que responde "a obra
# parou há quanto tempo?", pergunta que uma coluna não responde. Ver
# docs/field.md.
class ProgressReport < ApplicationRecord
  # Levantada quando alguém edita um relatório aprovado por um caminho que pula
  # as validações. Trilha reescrita não é trilha.
  class ApprovedReportIsImmutable < StandardError; end

  has_rich_text :summary
  has_rich_text :blockers

  belongs_to :project
  belongs_to :reported_by, class_name: "Profile", inverse_of: :progress_reports
  belongs_to :approved_by, class_name: "Profile", optional: true, inverse_of: :approved_progress_reports

  enum :status, { draft: 0, submitted: 1, approved: 2 }, validate: true

  scope :latest_first, -> { order(reported_on: :desc, id: :desc) }

  # `DISTINCT ON` é do Postgres, e o projeto é Postgres 18. A alternativa
  # portátil — subconsulta correlacionada com `MAX` — custa uma varredura por
  # obra, que é exatamente o N+1 que este escopo existe para evitar: o card de
  # 50 obras mostra percentual E data, e as duas saem daqui numa consulta só.
  #
  # O `order` faz parte do escopo e não pode ser trocado por quem chama: o
  # Postgres exige que a primeira expressão do `ORDER BY` case com o
  # `DISTINCT ON`. Reordene do lado de fora e a consulta reprova.
  scope :latest_per_project, lambda {
    approved.select("DISTINCT ON (project_id) *").order(:project_id, reported_on: :desc, id: :desc)
  }

  validates :reported_on, presence: true, comparison: { less_than_or_equal_to: -> { Date.current } }
  validates :physical_progress, numericality: { in: 0..100, only_integer: true }
  validates :workers_on_site, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :submitted_report_explains_itself
  validate :approved_report_is_not_edited, on: :update

  before_save :forbid_editing_an_approved_report
  after_save :refresh_project_progress

  def status_label
    I18n.t(status, scope: :statuses)
  end

  private

  # Vazio inclui `<div><br></div>`, que é o que o Trix envia quando ninguém
  # digitou nada — `body.present?` acha que isso é conteúdo. Ver docs/action-text.md.
  def summary_written? = summary.body&.to_plain_text&.strip.present?

  # Regressão de percentual É permitida: obra tem retrabalho, e bloqueá-la
  # obrigaria a mentir no relatório. O que ela exige é a explicação — que é a
  # mesma que a submissão já exige, então a regra é uma só.
  def submitted_report_explains_itself
    return if draft? || summary_written?

    errors.add(:summary, :blank)
  end

  # A aprovação É um update — ela grava `approved_by` e `approved_at`. Por isso
  # a guarda pergunta pelo estado ANTERIOR: `status_was`, e não `approved?`.
  # Um `before_update { raise if approved? }` bloquearia a própria aprovação.
  def already_approved? = status_was == "approved"

  def approved_report_is_not_edited
    return unless already_approved?

    errors.add(:base, :approved_report_is_immutable)
  end

  def forbid_editing_an_approved_report
    return unless persisted? && already_approved?

    raise ApprovedReportIsImmutable, id.to_s
  end

  # Só relatório aprovado move o cache da obra. Rascunho e submissão são
  # trabalho em curso — se movessem, a listagem mostraria número que ninguém
  # conferiu.
  def refresh_project_progress
    project.recalculate_physical_progress if saved_change_to_status? && approved?
  end
end
