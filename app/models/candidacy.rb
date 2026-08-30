# frozen_string_literal: true

# "Onde ela aplica para servir" — o registro que transforma interesse em fila
# auditável, e onde a triagem acontece antes de alguém viajar.
#
# `Candidacy`, e não `Application`: dentro de `module Legacy` um `Application`
# pelado resolve para `Legacy::Application` — a própria classe da aplicação
# Rails — antes de chegar no modelo. Ver docs/mobilization.md.
class Candidacy < ApplicationRecord
  include ScrubbedPhoto

  has_rich_text :motivation
  attaches_scrubbed_files :documents

  belongs_to :need
  belongs_to :profile, optional: true, inverse_of: :candidacies
  belongs_to :volunteer_group, optional: true
  belongs_to :decided_by, class_name: "Profile", optional: true, inverse_of: :decided_candidacies
  has_one :assignment, dependent: :destroy

  enum :candidacy_status, { submitted: 0, screening: 1, approved: 2, rejected: 3, withdrawn: 4 },
       validate: true, prefix: true

  # Enum, e não texto livre: o objetivo é conseguir responder "por que as
  # candidaturas caem" sem alguém ler 400 comentários.
  enum :rejection_reason,
       { no_availability: 0, missing_skill: 1, missing_credential: 2, need_closed: 3, other: 4 },
       validate: { allow_nil: true }, prefix: true

  scope :pending, -> { where(candidacy_status: %i[submitted screening]) }

  # Um por par, do lado que estiver preenchido. Os índices únicos são PARCIAIS,
  # e as validações precisam do `allow_nil` correspondente: sem ele, duas
  # candidaturas de grupo à mesma necessidade colidiriam por `profile_id` nulo.
  validates :profile_id, uniqueness: { scope: :need_id }, allow_nil: true
  validates :volunteer_group_id, uniqueness: { scope: :need_id }, allow_nil: true

  validate :exactly_one_candidate
  validate :need_is_still_open, on: :create
  validate :candidate_carries_the_required_credential

  before_save :stamp_the_decision

  def candidacy_status_label
    I18n.t(candidacy_status, scope: :candidacy_statuses)
  end

  def rejection_reason_label
    return if rejection_reason.blank?

    I18n.t(rejection_reason, scope: :rejection_reasons)
  end

  def candidate = profile || volunteer_group

  # Recandidatar depois de desistir REABRE o mesmo registro, e não cria um
  # segundo: o índice único parcial garante um por par, e a história fica num
  # lugar só em vez de virar duas linhas que discordam.
  def reapply
    update!(candidacy_status: :submitted, decided_at: nil, decided_by: nil, rejection_reason: nil)
  end

  private

  # O `CHECK` do banco diz o mesmo; a validação existe para a segunda tentativa
  # virar erro de formulário em vez de exceção de driver.
  def exactly_one_candidate
    return if profile.present? ^ volunteer_group.present?

    errors.add(:base, :one_candidate_only)
  end

  def need_is_still_open
    return if need.blank? || need.need_status_open? || need.need_status_partially_fulfilled?

    errors.add(:need, :closed)
  end

  # O gate de registro profissional é da NECESSIDADE: quem decide se aquela
  # vaga exige CREA é quem a abriu. Grupo não é gateado — quem responde pelo
  # registro é a pessoa que for alocada, e a alocação é individual.
  def candidate_carries_the_required_credential
    return if need.blank? || !need.requires_professional_registration?
    return if profile.blank? || profile.valid_professional_registration?

    errors.add(:profile, :missing_credential)
  end

  # A decisão carimba a si mesma: um `decided_at` escrito por controller
  # divergiria do estado na primeira vez que alguém esquecesse.
  def stamp_the_decision
    return unless candidacy_status_changed?

    self.decided_at = decided? ? Time.current : nil
  end

  def decided? = candidacy_status_approved? || candidacy_status_rejected?
end
