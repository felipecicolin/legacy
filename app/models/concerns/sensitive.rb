# frozen_string_literal: true

# Visibilidade de um registro que descreve obra em campo. A plataforma fala de
# bases missionárias em países perseguidos: listar uma delas com coordenada e
# responsável é risco físico para pessoas reais. Ver docs/visibility.md.
module Sensitive
  extend ActiveSupport::Concern

  LEVELS = { public: 0, restricted: 1, confidential: 2 }.freeze

  # Registro nasce fechado. Default aberto faz o esquecimento vazar; default
  # fechado faz o esquecimento só atrapalhar.
  DEFAULT_LEVEL = :restricted

  # Colunas que põem a obra no mapa. Registro confidential não as persiste —
  # dado que não existe não vaza por view, por log, por export nem por backup.
  PRECISE_LOCATION_ATTRIBUTES = %i[address latitude longitude].freeze

  # Levantada quando alguém grava coordenada em registro confidential por um
  # caminho que pula as validações (`save(validate: false)`).
  class PreciseLocationForbidden < StandardError; end

  included do
    # `scopes: false` porque o escopo que o enum geraria para o nível `public`
    # se chamaria `public` e colidiria com o `Module#public` do Ruby — o
    # Active Record levanta na definição. Os escopos que interessam são o
    # `visible_to` e o `hidden_from`, que perguntam por um contexto, não por
    # um nível solto.
    enum :sensitivity_level, LEVELS, default: DEFAULT_LEVEL, validate: true, scopes: false

    # `destroy` aqui, e `restrict_with_error` do lado do autor (ver `User`), e
    # a assimetria é o ponto: apagar a obra é a direção segura — some o dado
    # que expunha gente, e o log fica sem sujeito. Apagar o autor não tira
    # risco de ninguém, só tiraria o rastro de quem decidiu expor.
    has_many :sensitivity_changes, as: :record, dependent: :destroy

    # Relação, e não array, de propósito: o agregado anonimizado por região
    # (trilha:dados) sai de `hidden_from(context).group(:region_id)`, sem
    # precisar de um segundo caminho de SQL.
    scope :visible_to, ->(context) { where(sensitivity_level: context.allowed_levels) }
    scope :hidden_from, ->(context) { where.not(sensitivity_level: context.allowed_levels) }

    validate :confidential_stores_no_precise_location
    validate :relaxed_sensitivity_is_justified

    before_save :forbid_precise_location_on_confidential
    after_save :log_sensitivity_promotion
  end

  class_methods do
    # Intersecção com o schema real: o concern é abstrato e cada modelo
    # concreto guarda as colunas que guarda.
    def precise_location_attributes
      PRECISE_LOCATION_ATTRIBUTES & column_names.map(&:to_sym)
    end
  end

  # Única porta para afrouxar a restrição. `update` direto reprova na
  # validação: exposição sem autor e sem motivo não tem como ser revista.
  # A promoção viaja numa variável de instância, e não num atributo público,
  # porque ela vale por uma gravação só: quem a lê é a validação e o
  # `after_save` desta mesma chamada, e deixá-la exposta convidaria a "setar e
  # salvar depois" — que é exatamente o `update` direto que a auditoria coíbe.
  def promote_visibility!(level:, author:, justification:)
    @sensitivity_promotion = SensitivityPromotion.new(author:, justification:)
    update!(sensitivity_level: level)
  end

  # País sempre; região só para quem alcança o nível do registro. O modelo
  # concreto responde `country_label` e `region_label` — as tabelas de país e
  # de região são de outra issue, e o concern não precisa conhecê-las.
  def location_label(context)
    return country_label unless context.can_see_precise_location?(self)

    [region_label, country_label].compact_blank.join(" · ")
  end

  private

  def stored_precise_location
    self.class.precise_location_attributes.select { |name| self[name].present? }
  end

  def confidential_stores_no_precise_location
    return unless confidential?
    return if stored_precise_location.empty?

    errors.add(:base, :confidential_precise_location)
  end

  def forbid_precise_location_on_confidential
    return unless confidential?
    return if stored_precise_location.empty?

    raise PreciseLocationForbidden, stored_precise_location.join(", ")
  end

  # Um registro que ainda não existe parte do default: nascer aberto é
  # promoção como qualquer outra, e passa pela mesma auditoria.
  def sensitivity_relaxed?
    previous = LEVELS.fetch(new_record? ? DEFAULT_LEVEL : sensitivity_level_was.to_sym)
    current = LEVELS[sensitivity_level&.to_sym]

    current.present? && current < previous
  end

  def relaxed_sensitivity_is_justified
    return unless sensitivity_relaxed?
    return if @sensitivity_promotion&.justified?

    errors.add(:sensitivity_level, :promotion_requires_justification)
  end

  def log_sensitivity_promotion
    promotion = @sensitivity_promotion
    @sensitivity_promotion = nil
    levels = saved_change_to_sensitivity_level
    return if promotion.blank? || levels.blank?

    sensitivity_changes.create!(**promotion.to_h, to_level: levels.last,
                                                  from_level: levels.first || DEFAULT_LEVEL)
  end
end
