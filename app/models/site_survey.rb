# frozen_string_literal: true

# O levantamento como entregável, e não só como estado.
#
# `LEVANTAMENTO` é um dos cinco estados da obra, mas levantamento é trabalho com
# produto: visita, medição, diagnóstico, estimativa. Modelar só como enum joga
# fora justamente o que o engenheiro voluntário produz remotamente, antes de
# qualquer equipe viajar — que é a metade diferenciada do produto. Ver
# docs/field.md.
class SiteSurvey < ApplicationRecord
  include ScrubbedPhoto

  has_rich_text :findings
  has_rich_text :recommendations
  attaches_scrubbed_files :documents

  belongs_to :project
  belongs_to :surveyed_by, class_name: "Profile", inverse_of: :site_surveys

  # `draft` → `submitted` basta. Ciclo de revisão com aprovador e recusa é v2:
  # um workflow que ninguém opera é estado morto no banco.
  enum :status, { draft: 0, submitted: 1 }, validate: true

  validates :surveyed_on, presence: true, comparison: { less_than_or_equal_to: -> { Date.current } }
  validates :currency, presence: true, length: { is: 3 }
  validates :estimated_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :submitted_survey_has_findings

  def status_label
    I18n.t(status, scope: :statuses)
  end

  private

  # `NOT NULL` não alcança: o corpo vive em `action_text_rich_texts`, fora
  # desta tabela. E "vazio" inclui `<div><br></div>`, que é o que o Trix envia
  # quando ninguém digitou nada. Ver docs/action-text.md.
  def findings_written? = findings.body&.to_plain_text&.strip.present?

  def submitted_survey_has_findings
    return if draft? || findings_written?

    errors.add(:findings, :blank)
  end
end
