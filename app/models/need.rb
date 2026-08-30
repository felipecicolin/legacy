# frozen_string_literal: true

# O que falta numa base ou numa obra. É a necessidade que liga o campo ao
# voluntário e ao doador — sem ela estruturada não existe matching, e o
# matching é o produto. Ver docs/mobilization.md.
class Need < ApplicationRecord
  include Sensitive
  include ScrubbedPhoto

  # Habilidade é a única espécie que aponta para a taxonomia curada; as demais
  # descrevem coisa, dinheiro ou gente, e um `skill_id` nelas seria dado
  # decorativo que a busca acabaria filtrando por engano.
  SKILL_KIND = "skill"

  has_rich_text :description
  attaches_scrubbed_files :references

  belongs_to :ngo
  belongs_to :project, optional: true
  belongs_to :skill, optional: true
  has_many :candidacies, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :need_fulfillments, dependent: :destroy

  enum :need_kind, { skill: 0, material: 1, funding: 2, team: 3, equipment: 4 },
       validate: true, prefix: true
  enum :urgency, { low: 0, normal: 1, high: 2, critical: 3 }, validate: true, prefix: true
  enum :need_status, { open: 0, partially_fulfilled: 1, fulfilled: 2, cancelled: 3 },
       validate: true, prefix: true

  # Urgência e prazo primeiro, e não a data de criação: necessidade crítica em
  # obra parada tem de subir. O desempate por `id` deixa a ordem determinística
  # quando urgência e prazo empatam.
  scope :by_priority, -> { order(urgency: :desc, needed_by: :asc, id: :asc) }

  # O casamento com o voluntário. `where.not(skill_id: nil)` não entra porque
  # `need_kind_skill` já garante a presença — a validação abaixo cobra os dois
  # sentidos.
  scope :matching, lambda { |profile|
    need_status_open.need_kind_skill.where(skill_id: profile.skill_ids).by_priority
  }

  validates :title, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :fulfilled_quantity,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: :quantity }
  validates :currency, presence: true, length: { is: 3 }
  validates :estimated_value_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :skill_matches_the_kind
  validate :project_belongs_to_the_same_base

  before_validation :inherit_sensitivity, on: :create
  before_save :derive_status

  # Candidatura é PESSOA se oferecendo, e isso só responde a necessidade que
  # pede gente. Material, equipamento e dinheiro são atendidos por doação — um
  # "quero ajudar" ali convida a um formulário que não resolve o pedido.
  def served_by_person? = need_kind_skill? || need_kind_team?

  def need_kind_label
    I18n.t(need_kind, scope: :need_kinds)
  end

  def urgency_label
    I18n.t(urgency, scope: :urgencies)
  end

  def need_status_label
    I18n.t(need_status, scope: :need_statuses)
  end

  def remaining_quantity = quantity - fulfilled_quantity

  # A porta ÚNICA do abatimento, e a trava mora aqui.
  #
  # Sem `!` mesmo levantando: o `MissingSafeMethod` do reek exige uma
  # contraparte segura para todo método com `!` numa classe, e a contraparte
  # aqui não existe — abater "sem levantar" seria devolver `false` e deixar o
  # chamador decidir se conferiu. Mesma escolha de
  # `Project#recalculate_physical_progress`.
  #
  # `with_lock` faz `SELECT ... FOR UPDATE` e recarrega: duas alocações
  # simultâneas na última vaga viram duas transações em fila, e a segunda só lê
  # a quantidade depois de a primeira ter gravado — então ela vê zero vagas e
  # reprova na validação, em vez de as duas lerem o mesmo número antigo e
  # passarem. Ver docs/mobilization.md.
  def fulfill(source:, quantity: 1, fulfilled_at: Time.current)
    with_lock do
      fulfillment = need_fulfillments.create!(source: source, quantity: quantity, fulfilled_at: fulfilled_at)
      recount_fulfilled
      fulfillment
    end
  end

  # Cancelar estorna e reabre. Sem isto a necessidade fica fechada para sempre
  # e a plataforma mente sobre o que ainda falta.
  def release(source:)
    with_lock do
      need_fulfillments.where(source: source).destroy_all
      recount_fulfilled
    end
  end

  # `fulfilled_quantity` é DERIVADO da soma dos abatimentos, e este é o único
  # escritor dele — nunca um controller. `update!` e não `update_column` porque
  # é o `before_save` que faz o status seguir a quantidade.
  def recount_fulfilled
    update!(fulfilled_quantity: need_fulfillments.sum(:quantity))
  end

  def to_s = title

  private

  # Nos DOIS sentidos: `skill` sem habilidade é necessidade que o matching
  # nunca encontra, e `material` com habilidade é dado decorativo que a busca
  # acaba filtrando por engano.
  # A pergunta é sobre o OBJETO, e não sobre `skill_id`: numa necessidade ainda
  # não salva a associação já está montada e o id ainda é nulo, e perguntar
  # pelo id reprovaria um registro perfeitamente válido — com uma mensagem
  # sobre um campo que quem preencheu o formulário preencheu.
  def skill_matches_the_kind
    return if need_kind_skill? == skill.present?

    errors.add(:skill, need_kind_skill? ? :blank : :present)
  end

  # Sem isto o registro aponta para a base A pela coluna e para a base B pela
  # obra, e os dois rollups discordam — sem erro em lugar nenhum.
  def project_belongs_to_the_same_base
    return unless project
    return if project.ngo_id == ngo_id

    errors.add(:project, :other_ngo)
  end

  # Herda da obra quando há obra, e da base quando não há. Só APERTA, como toda
  # herança de sensibilidade neste domínio: abrir é `promote_visibility!`.
  def inherit_sensitivity
    source = project || ngo
    return unless source
    return if Sensitive::LEVELS.fetch(source.sensitivity_level.to_sym) <= own_rank

    self.sensitivity_level = source.sensitivity_level
  end

  def own_rank = Sensitive::LEVELS.fetch(sensitivity_level.to_sym, 0)

  # `need_status` é DERIVADO da comparação, nunca escrito à mão — senão a
  # listagem "o que ainda falta" e a soma dos abatimentos divergem em silêncio.
  # `cancelled` é decisão humana e escapa da derivação.
  def derive_status
    return if need_status_cancelled?

    self.need_status = derived_status
  end

  def derived_status
    return :fulfilled if remaining_quantity.zero?
    return :partially_fulfilled if fulfilled_quantity.positive?

    :open
  end
end
