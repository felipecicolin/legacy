# frozen_string_literal: true

# País como entidade de primeira classe, e não uma string dentro da obra: é
# dimensão de agregação do relatório do investidor, é o que resta de
# localização quando a base é confidential, e é onde vive a decisão editorial
# de risco que dita a sensibilidade padrão. Ver docs/vocabulary.md.
class Country < ApplicationRecord
  has_many :regions, dependent: :destroy, inverse_of: :country

  # `restrict_with_error`, e não cascata: apagar um país com base é sempre
  # erro humano, e a cascata levaria junto obra e prestação de contas.
  has_many :ngos, dependent: :restrict_with_error, inverse_of: :country
  has_many :events, dependent: :restrict_with_error

  # Mesmo vocabulário do `Sensitive`, e vindo dele: o nível com que uma obra
  # criada aqui nasce é um nível como qualquer outro, e duas listas divergindo
  # é questão de tempo. `scopes: false` pelo mesmo motivo de lá — o escopo que
  # o valor `public` geraria colidiria com o `Module#public` do Ruby.
  enum :default_sensitivity, Sensitive::LEVELS, validate: true, scopes: false

  validates :iso_code, presence: true, uniqueness: true, length: { is: 2 }, format: { with: /\A[A-Z]{2}\z/ }
  validates :iso3_code, presence: true, uniqueness: true, length: { is: 3 }, format: { with: /\A[A-Z]{3}\z/ }
  validates :currency_code, length: { is: 3 }, format: { with: /\A[A-Z]{3}\z/ }, allow_nil: true

  # `presence` reprovaria `false`, que é o valor da esmagadora maioria das
  # linhas. O que se cobra é que a coluna esteja decidida — nunca `nil`.
  validates :high_risk, inclusion: { in: [true, false] }

  # O gancho que faz a política de segurança funcionar sozinha: base criada num
  # país marcado nasce `confidential` sem ninguém lembrar de marcar.
  #
  # Ele só APERTA. Desmarcar `high_risk` não devolve o país ao default, porque
  # afrouxar restrição é decisão explícita em toda a plataforma — e porque o
  # país deixar de ser perigoso não é um fato que um `update` de linha de
  # vocabulário deva afirmar sozinho.
  before_validation :tighten_default_sensitivity, if: :high_risk?

  # O seed lê o YAML curado em vez de redigitar a lista: duas listas divergindo
  # é questão de tempo. `find_or_initialize_by` + `update!` em vez de
  # `find_or_create_by!` porque a curadoria muda — marcar um país como
  # `high_risk` no YAML tem de alcançar a linha que já existe, e não só as
  # próximas.
  def self.load_vocabulary!
    Vocabulary::Catalog.countries.entries.each do |entry|
      find_or_initialize_by(iso_code: entry.fetch(:iso_code)).update!(entry)
    end
  end

  # O nome sai do locale, por `countries.<iso_code em minúsculas>`.
  #
  # `scope:` com o valor em variável, e não `t("countries.#{...}")`: o cop
  # `I18n/RailsI18n/DecorateStringFormattingUsingInterpolation` proíbe
  # interpolação dentro da chave. As ~250 entradas são invisíveis para o
  # scanner do i18n-tasks, e quem responde por elas é
  # `spec/models/vocabulary/catalog_spec.rb` — ver config/i18n-tasks.yml.erb.
  # `default:` com o próprio código, e não uma chave que falta.
  #
  # Todo país CURADO tem rótulo — `spec/models/vocabulary/catalog_spec.rb`
  # compara os dois lados e reprova qualquer um sem. O que este default cobre é
  # o país que não veio da curadoria: a faixa de uso privado do ISO 3166-1
  # (XA–XZ), que é o que fixture e seed de desenvolvimento usam para não
  # nomear país real em dado fictício. Sem ele a tela exibe
  # "Translation missing" para quem abrir a demo.
  def name
    I18n.t(iso_code.downcase, scope: :countries, default: iso_code)
  end

  private

  def tighten_default_sensitivity
    self.default_sensitivity = :confidential
  end
end
