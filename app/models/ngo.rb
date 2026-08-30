# frozen_string_literal: true

# A ONG. Lugar durável e instituição que responde por ele são a MESMA coisa
# aqui — igreja, escola, moradia, clínica, empresa ou associação —, e é ela que
# acumula obras ao longo dos anos, publica necessidade mesmo sem obra ativa,
# recebe doação e envia equipe. Ver docs/ngos.md.
#
# Pessoa continua sendo `Profile`, e o vínculo entre as duas, com papel, é
# `Membership`: papel é contexto, nunca coluna em `profiles`.
class Ngo < ApplicationRecord
  include Sensitive

  # Bytes do sufixo de desempate do slug. Três bytes dão 16 milhões de valores:
  # o suficiente para que a segunda "Igreja Batista" não dependa de sorte, e
  # curto o bastante para caber numa URL legível.
  SLUG_SUFFIX_BYTES = 3

  has_rich_text :description
  has_one_attached :logo
  has_one_attached :cover_image

  belongs_to :country, optional: true
  belongs_to :region, optional: true

  has_many :memberships, dependent: :destroy
  has_many :profiles, through: :memberships

  # `restrict_with_error`, e não `destroy`: apagar ONG com obra é sempre erro
  # humano, e o histórico da obra é prestação de contas. Some a obra, some a
  # resposta para "onde foi parar o dinheiro".
  has_many :projects, dependent: :restrict_with_error
  has_many :campaigns, dependent: :restrict_with_error
  has_many :disbursements, dependent: :restrict_with_error
  has_many :deployments, dependent: :restrict_with_error
  has_many :volunteer_groups, dependent: :restrict_with_error
  has_many :partnerships, dependent: :restrict_with_error
  has_many :donated_in_kind_donations, as: :donor, class_name: "InKindDonation",
                                       dependent: :restrict_with_error

  # `has_many :needs` direto é o que permite a ONG ter necessidade SEM obra
  # ativa — "precisamos de um engenheiro para avaliar a estrutura" existe antes
  # de qualquer obra ser aberta.
  has_many :needs, dependent: :destroy
  has_many :volunteer_engagements, dependent: :nullify
  has_many :contributions, as: :contributor, dependent: :nullify

  # `prefix: true` nos dois: sem ele o enum define `association?` e o escopo
  # `Ngo.association`, que disputam nome com a API de associação do Active
  # Record. O rótulo de UI não muda — ele sai de `<enum no plural>.<valor>`.
  enum :ngo_kind, { church: 0, school: 1, housing: 2, clinic: 3, company: 4, association: 5 },
       validate: true, prefix: true

  # `approved` e `active` eram o mesmo estado com dois nomes e viraram um.
  # `inactive` sobrevive separado de `suspended`: ONG que encerrou atividade não
  # é ONG punida, e colapsar as duas apagaria o motivo.
  enum :ngo_status, { pending: 0, active: 1, suspended: 2, inactive: 3 },
       validate: true, prefix: true

  # A ONG nasce `pending`: quem não foi aprovado não aparece em busca pública e
  # não recebe doação. Este escopo é o único lugar que decide isso.
  scope :visible, -> { ngo_status_active }

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :people_served, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Faixa da coordenada, e não só a ausência dela em registro confidential: uma
  # latitude de 200 não localiza nada e não dá erro em lugar nenhum — o mapa
  # simplesmente não desenha o ponto, e ninguém descobre por quê.
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true

  # URL pública que quebra é dívida permanente: quem já compartilhou o link não
  # tem como saber que ele mudou. `update_all` e SQL cru passam por baixo.
  attr_readonly :slug

  validate :region_belongs_to_the_country

  before_validation :assign_slug, on: :create

  # O gancho que faz a política de segurança funcionar sozinha: ONG num país
  # marcado como `high_risk` nasce `confidential` sem ninguém lembrar de marcar.
  before_validation :inherit_country_sensitivity, on: :create

  def ngo_kind_label
    I18n.t(ngo_kind, scope: :ngo_kinds)
  end

  def ngo_status_label
    I18n.t(ngo_status, scope: :ngo_statuses)
  end

  # O que `Sensitive#location_label` pergunta ao modelo concreto: o concern não
  # conhece as tabelas de país e de região, e por isso pede rótulo.
  def country_label = country&.name

  def region_label = region&.name

  def to_s = name

  private

  # Sem ela a ONG aponta para um país pela coluna e para outro pela região, e o
  # rollup por país discorda do mapa — sem erro em lugar nenhum.
  def region_belongs_to_the_country
    return unless region
    return if region.country_id == country_id

    errors.add(:region, :other_country)
  end

  # O slug nasce do nome, mas fica ARMAZENADO — derivar em tempo de leitura
  # faria a correção de um nome reescrever a URL de todo mundo que já a tem.
  def assign_slug
    self.slug = slug.presence || unique_slug
  end

  def unique_slug
    base = name.to_s.parameterize
    return base unless self.class.exists?(slug: base)

    "#{base}-#{SecureRandom.hex(SLUG_SUFFIX_BYTES)}"
  end

  # Só APERTA. Comparar por rank, e não por igualdade, é o que impede a herança
  # de AFROUXAR: uma ONG criada num país `public` mantém o `restricted` que o
  # concern deu como default, porque abrir é promoção auditada.
  def inherit_country_sensitivity
    return unless country

    inherited = Sensitive::LEVELS.fetch(country.default_sensitivity.to_sym)
    return if inherited <= Sensitive::LEVELS.fetch(sensitivity_level.to_sym)

    self.sensitivity_level = country.default_sensitivity
  end
end
