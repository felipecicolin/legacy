# frozen_string_literal: true

module Search
  # A busca unificada: obra, base e país na mesma caixa.
  #
  # Três consultas e não uma `UNION`, porque os três tipos têm colunas,
  # políticas e telas diferentes — juntá-los em SQL obrigaria a projetar tudo
  # numa forma comum e a desfazer isso na view. O que eles compartilham é a
  # PERGUNTA, não a linha. Ver docs/search.md.
  Query = Data.define(:term, :filters, :context) do
    # Cada grupo pergunta ao seu próprio escopo de visibilidade: obra e base
    # passam por `visible_to`, e é isso que faz uma obra confidencial não
    # aparecer nem como "sem permissão" — a busca não pode virar oráculo.
    def groups
      { projects: projects, mission_bases: mission_bases, countries: countries }
    end

    def any_result? = groups.any? { |_type, records| records.any? }

    def total = groups.sum { |_type, records| records.count }

    def searching? = term.present?

    def filtering? = filters.any?

    # O estado inteiro numa hash, para o link do alternador reproduzi-lo: é o
    # que faz trocar de apresentação não perder filtro nem termo.
    def to_query = { query: term }.compact.merge(filters.to_query)

    # O filtro de país oferece só os países que TÊM base alcançável. A lista
    # curada tem 249, e oferecer as 249 seria pedir para a pessoa escolher
    # entre 244 filtros que devolvem nada — e, pior, deixar o alcance dela
    # visível pelo que a lista NÃO oferece.
    def filterable_countries
      Country.where(id: visible_bases.select(:country_id)).order(:iso_code)
    end

    private

    def visible_bases = MissionBase.visible_to(context.visibility).visible

    def projects
      Project.visible_to(context.visibility)
             .then { |scope| filters.apply_to_projects(scope) }
             .then { |scope| matching(scope, :title) }
             .includes(:mission_base).order(:code)
    end

    def mission_bases
      visible_bases.then { |scope| filters.apply_to_mission_bases(scope) }
                   .then { |scope| matching(scope, :name) }
                   .includes(:country).order(:name)
    end

    # País não vira página de país: ele é um RECORTE, e a tela leva o termo
    # para o filtro.
    def countries
      matching_countries(filterable_countries)
    end

    # O nome do país vive no LOCALE, não numa coluna — é `countries.<iso>`. Por
    # isso o casamento acontece em Ruby: não há texto no banco contra o qual
    # comparar. A lista já vem restrita aos países com base alcançável.
    def matching_countries(scope)
      return scope unless searching?

      scope.select { |country| I18n.transliterate(country.name).downcase.include?(needle) }
    end

    # `unaccent` na consulta, dos dois lados: "sao paulo" acha "São Paulo" e
    # "São Paulo" acha "sao paulo". Sem o lado de cá a busca só funcionaria
    # para quem já digita como o dado está gravado.
    def matching(scope, column)
      return scope unless searching?

      scope.where("unaccent(lower(#{column})) like unaccent(lower(?))", "%#{term.strip}%")
    end

    def needle = I18n.transliterate(term.to_s).downcase
  end
end
