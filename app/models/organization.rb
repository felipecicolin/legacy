# frozen_string_literal: true

# A instituição. Igreja, empresa, ONG e agência missionária entram na
# plataforma por aqui — é a organização que financia uma obra e que envia uma
# equipe, e é por ela que a mesma pessoa pode representar dois lados.
#
# Pessoa continua sendo `Profile`. O vínculo entre as duas, com papel, é
# `Membership`. Ver docs/organizations.md.
class Organization < ApplicationRecord
  # Bytes do sufixo de desempate do slug. Três bytes (seis dígitos hex) dão 16
  # milhões de valores: o suficiente para que a segunda "Igreja Batista" não
  # dependa de sorte, e curto o bastante para caber numa URL legível.
  SLUG_SUFFIX_BYTES = 3

  has_many :memberships, dependent: :destroy
  has_many :profiles, through: :memberships

  # `nullify`, e não `restrict`: a base sobrevive à organização que a
  # operava. Quem opera pode mudar — e uma base sem operador declarado é
  # estado legítimo, ao contrário de uma base sem país.
  has_many :mission_bases, dependent: :nullify, inverse_of: :organization
  has_many :volunteer_groups, dependent: :restrict_with_error
  has_many :volunteer_engagements, dependent: :nullify
  has_many :partnerships, dependent: :restrict_with_error
  has_many :contributions, as: :contributor, dependent: :nullify
  has_many :donated_in_kind_donations, as: :donor, class_name: "InKindDonation", dependent: :restrict_with_error

  has_rich_text :description
  has_one_attached :logo

  # `validate: true` em vez do padrão que levanta `ArgumentError`: valor de
  # enum chega de formulário, e um `params[:organization_kind]` adulterado tem
  # de virar erro de campo, não exceção de 500.
  enum :organization_kind, { church: 0, company: 1, ngo: 2, mission_agency: 3 }, validate: true
  enum :organization_status, { pending: 0, approved: 1, suspended: 2 }, validate: true

  # A organização nasce `pending`: quem não foi aprovado não aparece em busca e
  # não recebe doação. Este escopo é o único lugar que decide isso.
  scope :visible, -> { approved }

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  # URL pública que quebra é dívida permanente: quem já compartilhou o link não
  # tem como saber que ele mudou. Com o default 8.1 o `attr_readonly` levanta
  # `ActiveRecord::ReadonlyAttributeError` na atribuição em registro já
  # persistido — renomear a organização segue possível, mudar o endereço dela
  # não. O alcance é o mesmo do `attr_readonly` de `PaymentTransaction`:
  # `update_all` e SQL cru passam por baixo.
  attr_readonly :slug

  before_validation :assign_slug, on: :create

  # Nenhum valor de enum vai cru para a tela — a convenção é `<enum no
  # plural>.<valor>` no topo do locale, e está em docs/i18n.md. `scope:` com o
  # valor em variável porque o cop
  # `I18n/RailsI18n/DecorateStringFormattingUsingInterpolation` proíbe montar a
  # chave por interpolação.
  def kind_label
    I18n.t(organization_kind, scope: :organization_kinds)
  end

  def status_label
    I18n.t(organization_status, scope: :organization_statuses)
  end

  def to_s = name

  private

  # O slug nasce do nome, mas fica ARMAZENADO — derivar em tempo de leitura
  # faria a correção de um nome reescrever a URL de todo mundo que já a tem.
  #
  # `presence` e não `||=`: um campo de slug deixado em branco no formulário
  # chega como `""`, que é truthy, e o default não correria.
  def assign_slug
    self.slug = slug.presence || unique_slug
  end

  # Dois nomes iguais dão dois slugs iguais, e o índice único reprovaria a
  # segunda organização com um erro sobre um campo que ninguém preencheu. O
  # sufixo é a saída. Ele não fecha a corrida entre dois cadastros simultâneos
  # — quem fecha é o índice —, mas tira o caso comum do caminho do erro.
  def unique_slug
    base = name.to_s.parameterize
    return base unless self.class.exists?(slug: base)

    "#{base}-#{SecureRandom.hex(SLUG_SUFFIX_BYTES)}"
  end
end
