# frozen_string_literal: true

# O lugar durável. Uma base — base missionária, ONG, escola, moradia, igreja,
# clínica — acumula várias obras ao longo dos anos e tem necessidade mesmo sem
# obra ativa.
#
# **Base não é obra**, e essa é a decisão que não dá para desfazer barato.
# Fundir as duas é tentador ("a obra É a base") e quebra três coisas de uma vez:
# a candidatura do voluntário a uma necessidade da base sem obra, a necessidade
# recorrente, e o rollup por país. O campo de busca do design system já separa
# — "obra, base ou país". Ver docs/field.md.
class MissionBase < ApplicationRecord
  include Sensitive

  # Sufixo de desempate do slug, nos mesmos moldes de `Organization`.
  SLUG_SUFFIX_BYTES = 3

  has_rich_text :description
  has_one_attached :cover_image

  belongs_to :country
  belongs_to :region, optional: true
  belongs_to :organization, optional: true

  # `restrict_with_error`, e não `destroy`: apagar base com obra é sempre erro
  # humano, e o histórico da obra é prestação de contas. Some a obra, some a
  # resposta para "onde foi parar o dinheiro".
  has_many :projects, dependent: :restrict_with_error

  # `has_many :needs` direto é o que permite a base ter necessidade SEM obra
  # ativa — o caso que a fusão Base/Obra destruiria, e a razão de as duas serem
  # tabelas diferentes.
  has_many :needs, dependent: :destroy
  has_many :deployments, dependent: :restrict_with_error

  # Os nomes não são `kind` e `status` porque o rótulo de UI sai de `<enum no
  # plural>.<valor>` (docs/i18n.md), e `kinds.*` já é o vocabulário de
  # `Credential` e de `PaymentTransaction`. Mesma razão de
  # `Organization#organization_kind`.
  enum :base_kind, { mission_base: 0, ngo: 1, school: 2, housing: 3, church: 4, clinic: 5 }, validate: true

  # A base nasce `pending`: quem não foi aprovado não aparece em busca pública
  # e não recebe doação. Este escopo é o único lugar que decide isso.
  enum :base_status, { pending: 0, active: 1, inactive: 2 }, validate: true, prefix: true

  scope :visible, -> { base_status_active }

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :people_served, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Faixa da coordenada, e não só a ausência dela em registro confidencial: uma
  # latitude de 200 não localiza nada e não dá erro em lugar nenhum — o mapa
  # simplesmente não desenha o ponto, e ninguém descobre por quê.
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true

  # URL pública que quebra é dívida permanente — quem já compartilhou o link não
  # tem como saber que mudou. Mesmo alcance do `attr_readonly` de
  # `Organization#slug`: `update_all` e SQL cru passam por baixo.
  attr_readonly :slug

  validate :region_belongs_to_the_country

  before_validation :assign_slug, on: :create

  # O gancho que faz a política de segurança funcionar sozinha: base num país
  # marcado como `high_risk` nasce `confidential` sem ninguém lembrar de marcar.
  # Ele só APERTA — afrouxar é decisão explícita, por `promote_visibility!`.
  before_validation :inherit_country_sensitivity, on: :create

  def base_kind_label
    I18n.t(base_kind, scope: :base_kinds)
  end

  def base_status_label
    I18n.t(base_status, scope: :base_statuses)
  end

  # O que `Sensitive#location_label` pergunta ao modelo concreto: o concern não
  # conhece as tabelas de país e de região, e é por isso que ele pede rótulo em
  # vez de associação.
  def country_label = country.name

  def region_label = region&.name

  def to_s = name

  private

  # A mesma classe de invariante de coerência que `Need` cobra entre obra e
  # base: sem ela a base aponta para um país pela coluna e para outro pela
  # região, e o rollup por país discorda do mapa — sem erro em lugar nenhum.
  def region_belongs_to_the_country
    return unless region
    return if region.country_id == country_id

    errors.add(:region, :other_country)
  end

  def assign_slug
    self.slug = slug.presence || unique_slug
  end

  def unique_slug
    base = name.to_s.parameterize
    return base unless self.class.exists?(slug: base)

    "#{base}-#{SecureRandom.hex(SLUG_SUFFIX_BYTES)}"
  end

  # Só aperta. Comparar por rank, e não por igualdade, é o que impede a
  # herança de AFROUXAR: uma base criada num país `public` mantém o
  # `restricted` que o concern deu como default, porque abrir é promoção e
  # promoção pede autor e justificativa.
  def inherit_country_sensitivity
    inherited = Sensitive::LEVELS.fetch(country.default_sensitivity.to_sym)
    return if inherited <= Sensitive::LEVELS.fetch(sensitivity_level.to_sym)

    self.sensitivity_level = country.default_sensitivity
  end
end
