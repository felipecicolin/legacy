# frozen_string_literal: true

# A obra. Episódica, com escopo, prazo e orçamento próprios, e pertencente a
# uma base que a antecede e a sobrevive. Ver docs/field.md.
class Project < ApplicationRecord
  include Sensitive

  # Exatamente os cinco estados do design system. O `StatusBadgeComponent` (#8)
  # tem de casar com esta lista — a reconciliação é um spec que compara as duas
  # constantes, e ele entra com quem chegar por último.
  STATUSES = { surveying: 0, in_progress: 1, paused: 2, urgent: 3, completed: 4 }.freeze

  # `completed` é terminal: reabrir obra é criar obra nova, senão o histórico de
  # prestação de contas fica ambíguo — o mesmo código responderia por dois
  # ciclos com orçamentos diferentes.
  TRANSITIONS = {
    "surveying" => %w[in_progress paused],
    "in_progress" => %w[paused urgent completed],
    "paused" => %w[in_progress urgent],
    "urgent" => %w[in_progress paused completed],
    "completed" => [],
  }.freeze

  # Levantada quando alguém força uma transição por um caminho que pula as
  # validações (`update_column`, `save(validate: false)`). Espelha o que
  # `Sensitive` faz com a coordenada, e pelo mesmo motivo: a validação pega o
  # caminho do formulário, e isto pega o resto.
  class InvalidTransition < StandardError; end

  has_rich_text :scope_description

  belongs_to :mission_base
  has_many :progress_reports, dependent: :destroy
  has_many :needs, dependent: :destroy
  has_many :deployments, dependent: :nullify
  has_many :site_surveys, dependent: :destroy
  has_many :project_participations, dependent: :destroy
  has_many :participants, through: :project_participations, source: :profile

  # `destroy`: a foto pertence à obra e não sobrevive a ela. O blob vai junto
  # pelo `dependent: :purge_later` que o Active Storage instala.
  has_many :project_photos, dependent: :destroy

  enum :status, STATUSES, validate: true

  validates :title, presence: true

  # `code` é gerada pelo banco e o Rails nunca a escreve — a unicidade real vem
  # da sequence de `code_number` e da fórmula ser injetora. O validador existe
  # porque toda unicidade de índice neste repositório tem um par no modelo
  # (é o que o `database_consistency` cobra), e o `allow_nil` é o que o impede
  # de consultar na criação, quando o valor ainda não existe.
  validates :code, uniqueness: true, allow_nil: true
  validates :funding_target_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :physical_progress, numericality: { in: 0..100, only_integer: true }
  validates :currency, presence: true, length: { is: 3 }

  validate :transition_is_allowed, on: :update
  validate :work_in_progress_has_a_coordinator, on: :update
  validate :not_less_restrictive_than_base

  before_validation :inherit_base_sensitivity, on: :create
  before_save :forbid_forced_transition

  def status_label
    I18n.t(status, scope: :statuses)
  end

  # O valor de verdade do avanço é o do relatório aprovado MAIS RECENTE, e não
  # o maior: obra tem retrabalho, e uma regressão de 62% para 55% é um fato que
  # o cache tem de refletir. A coluna existe para ordenar e filtrar sem N+1, e
  # este é o único escritor dela — chamado pelo `ProgressReport`, nunca por
  # controller.
  def recalculate_physical_progress
    update_column(:physical_progress, progress_reports.approved.latest_first.pick(:physical_progress) || 0)
  end

  def to_s = code

  private

  def allowed_next_states = TRANSITIONS.fetch(status_was, [])

  def forced_transition? = status_changed? && persisted? && allowed_next_states.exclude?(status)

  def transition_is_allowed
    return unless forced_transition?

    errors.add(:status, :transition_not_allowed)
  end

  # Cobrado na TRANSIÇÃO para `in_progress`, e não na criação: obra em
  # levantamento ainda não tem equipe, e exigir coordenador desde o cadastro
  # obrigaria a inventar um.
  #
  # Só validação, sem a guarda que levanta do outro lado: um `save(validate:
  # false)` aqui não abre porta de segurança nenhuma — deixa a obra sem quem
  # responda por ela, que é problema de processo e aparece na primeira tela.
  def work_in_progress_has_a_coordinator
    return unless status_changed? && in_progress?
    return if project_participations.reporting.exists?(participation_role: :coordinator)

    errors.add(:status, :in_progress_without_coordinator)
  end

  def forbid_forced_transition
    return unless forced_transition?

    raise InvalidTransition, "#{status_was} -> #{status}"
  end

  # A obra herda o nível da base na criação, e a herança só APERTA — mesma
  # regra da base em relação ao país.
  def inherit_base_sensitivity
    return unless mission_base && own_rank
    return if base_rank <= own_rank

    self.sensitivity_level = mission_base.sensitivity_level
  end

  def base_rank = Sensitive::LEVELS.fetch(mission_base.sensitivity_level.to_sym)

  # `[]` e não `fetch`: com `validate: true` um nível inválido chega até aqui
  # como string solta, e é a validação do enum que tem de reprová-lo — não um
  # `KeyError` no meio de outra regra.
  def own_rank = Sensitive::LEVELS[sensitivity_level&.to_sym]

  # O piso vale para sempre, e não só na criação: a base pode ser apertada
  # depois, e uma obra que ficasse mais aberta que a base dela seria justamente
  # a porta que a promoção da base tentou fechar.
  def not_less_restrictive_than_base
    return unless mission_base && own_rank
    return if own_rank >= base_rank

    errors.add(:sensitivity_level, :below_mission_base)
  end
end
