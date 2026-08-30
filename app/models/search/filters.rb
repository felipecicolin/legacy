# frozen_string_literal: true

module Search
  # O estado da busca que não é o termo. Ele vive na QUERY STRING inteiro:
  # filtro que não sobrevive ao compartilhamento do link não serve para
  # trabalho em equipe. Ver docs/search.md.
  #
  # Valor inválido é IGNORADO, não recusado: a URL é escrita por gente, e um
  # `?status=demolida` colado errado tem de devolver a lista sem o filtro — não
  # uma exceção nem uma lista vazia que se lê como "não existe nada".
  # Fora do bloco do `Data.define`: constante declarada dentro de bloco é
  # atribuição dinâmica, e o `Lint/ConstantDefinitionInBlock` reprova.
  FILTER_NAMES = %i[status country_id base_kind urgency min_progress].freeze

  Filters = Data.define(*FILTER_NAMES) do
    def self.from(params)
      new(**FILTER_NAMES.index_with { |name| params[name].presence })
    end

    def any? = to_h.compact.any?

    def apply_to_projects(scope)
      scope.then { |relation| by_status(relation) }
           .then { |relation| by_country(relation) }
           .then { |relation| by_progress(relation) }
    end

    def apply_to_mission_bases(scope)
      scope.then { |relation| relation.where(country_id: country_id) if country_id }
           .then { |relation| by_base_kind(relation || scope) }
    end

    def to_query = to_h.compact

    private

    def by_status(scope)
      Project.statuses.key?(status) ? scope.where(status: status) : scope
    end

    def by_country(scope)
      return scope if country_id.blank?

      scope.where(mission_base: MissionBase.where(country_id: country_id))
    end

    def by_progress(scope)
      return scope if min_progress.blank?

      scope.where(physical_progress: Integer(min_progress, exception: false).to_i..)
    end

    def by_base_kind(scope)
      MissionBase.base_kinds.key?(base_kind) ? scope.where(base_kind: base_kind) : scope
    end
  end
end
