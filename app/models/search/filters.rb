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
  FILTER_NAMES = %i[status country_id ngo_kind urgency min_progress].freeze

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

    # A mesma gramática de filtro serve a busca e o painel do voluntário: são
    # os mesmos nomes na mesma query string, e duas gramáticas divergiriam.
    def apply_to_needs(scope)
      scope.then { |relation| by_need_kind(relation) }
           .then { |relation| by_urgency(relation) }
           .then { |relation| by_country_of_base(relation) }
    end

    def apply_to_ngos(scope)
      scope.then { |relation| relation.where(country_id: country_id) if country_id }
           .then { |relation| by_ngo_kind(relation || scope) }
    end

    def to_query = to_h.compact

    private

    def by_status(scope)
      Project.statuses.key?(status) ? scope.where(status: status) : scope
    end

    def by_country(scope)
      return scope if country_id.blank?

      scope.where(ngo: Ngo.where(country_id: country_id))
    end

    def by_progress(scope)
      return scope if min_progress.blank?

      scope.where(physical_progress: Integer(min_progress, exception: false).to_i..)
    end

    def by_need_kind(scope)
      Need.need_kinds.key?(status) ? scope.where(need_kind: status) : scope
    end

    def by_urgency(scope)
      Need.urgencies.key?(urgency) ? scope.where(urgency: urgency) : scope
    end

    def by_country_of_base(scope)
      return scope if country_id.blank?

      scope.where(ngo: Ngo.where(country_id: country_id))
    end

    def by_ngo_kind(scope)
      Ngo.ngo_kinds.key?(ngo_kind) ? scope.where(ngo_kind: ngo_kind) : scope
    end
  end
end
