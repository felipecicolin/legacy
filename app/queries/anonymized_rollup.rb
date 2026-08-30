# frozen_string_literal: true

# Agregado anonimizado por região: quem não pode ver uma obra individualmente
# recebe "N obras · progresso médio" no lugar dela, nunca o registro. Ver
# docs/visibility.md.
#
# Só o que dá pra provar com dado real hoje: contagem de obras ocultas e
# progresso físico médio, por região. A soma de dinheiro arrecadado entra
# quando #39 (Campaign) existir — hoje não há tabela de arrecadação nenhuma.
class AnonymizedRollup
  # Piso de k-anonimato: agregado sobre menos de 3 obras é o próprio registro
  # com outro nome (docs/visibility.md).
  MINIMUM_GROUP_SIZE = 3

  Row = Data.define(:country_id, :country_name, :region_id, :region_name,
                    :project_count, :average_physical_progress)

  # Resolve nome de país e de região com duas queries constantes, não uma por
  # grupo publicado — é o que sustenta "contagem de query independente do
  # número de obras".
  class Lookups
    def initialize(keys)
      @countries = Country.where(id: keys.map(&:first)).index_by(&:id)
      @regions = Region.where(id: keys.filter_map(&:last)).index_by(&:id)
    end

    def row_for(key, count, average)
      country_id, region_id = key
      Row.new(country_id: country_id, country_name: @countries.fetch(country_id).name,
              region_id: region_id, region_name: region_id && @regions.fetch(region_id).name,
              project_count: count, average_physical_progress: average.to_f.round)
    end
  end
  private_constant :Lookups

  def initialize(visibility)
    @visibility = visibility
  end

  def by_region
    counts = grouped_projects.count
    published = counts.select { |_key, count| count >= MINIMUM_GROUP_SIZE }
    averages = grouped_projects.average(:physical_progress)
    lookups = Lookups.new(published.keys)

    published.map { |key, count| lookups.row_for(key, count, averages.fetch(key)) }
  end

  private

  def grouped_projects
    Project.hidden_from(@visibility).joins(:mission_base)
           .group("mission_bases.country_id", "mission_bases.region_id")
  end
end
