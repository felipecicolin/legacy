# frozen_string_literal: true

# As obras que um investidor financia: a fatia dele em cada uma, e o que ele
# não alcança reduzido a agregado anonimizado. Ver docs/investor-dashboard.md.
#
# Classe própria, e não mais métodos no painel: o painel responde "quanto e
# quantos", e isto responde "em quais" — duas perguntas com estados diferentes.
class FundedProjects
  # Uma obra financiada, já com a fatia calculada. Objeto de valor e não hash:
  # a view lê `stake.attributed_reach`, e um `[:reach]` que some vira `nil` em
  # tela em vez de erro.
  Stake = Data.define(:project, :contributed_cents, :attributed_reach)

  # O que sobra quando as obras não podem ser detalhadas: contagem, dinheiro e
  # alcance, sem nome, sem ONG e sem lugar.
  Aggregate = Data.define(:project_count, :contributed_cents, :attributed_reach)

  # Mesmo piso do agregado de campanha. O repositório tem UM número para
  # "poucos demais para anonimizar", e um segundo divergiria do primeiro na
  # primeira vez que alguém mexesse em um deles.
  MINIMUM_AGGREGATE_COUNT = Campaign::MINIMUM_AGGREGATE_COUNT

  def initialize(contributions, visibility)
    @contributions = contributions
    @visibility = visibility
  end

  def stakes
    @stakes ||= visible.map { |project| stake_for(project) }
  end

  def active_stakes
    @active_stakes ||= stakes.reject { |stake| stake.project.completed? }
  end

  def hidden
    @hidden ||= aggregate_of(scope.hidden_from(@visibility).to_a)
  end

  # Abaixo do piso o agregado descreveria quase uma obra só — e como o
  # investidor sabe a que campanha deu, o que sobraria de segredo é exatamente
  # o que a obra confidencial esconde.
  def hidden_disclosable? = hidden.project_count >= MINIMUM_AGGREGATE_COUNT

  # A tela tem de DIZER que encolheu: número menor sem explicação se lê como
  # número errado, e a pessoa vai procurar o dinheiro que sumiu.
  def hidden_withheld? = hidden.project_count.positive? && !hidden_disclosable?

  def contributed_in_projects_cents = contributed_by_project.values.sum

  def disclosable(field)
    hidden_disclosable? ? hidden.public_send(field) : 0
  end

  private

  # `{project_id => centavos}`, numa consulta só. O `where.not` é o que separa
  # aporte em obra de aporte na ONG.
  def contributed_by_project
    @contributed_by_project ||=
      @contributions.joins(:campaign).where.not(campaigns: { project_id: nil })
                    .group("campaigns.project_id").sum(:amount_cents)
  end

  def scope
    @scope ||= Project.where(id: contributed_by_project.keys)
  end

  def visible
    @visible ||= scope.visible_to(@visibility).includes(:ngo).to_a
  end

  def stake_for(project)
    cents = contributed_by_project.fetch(project.id, 0)
    Stake.new(project: project, contributed_cents: cents,
              attributed_reach: project.reach_for(cents))
  end

  def aggregate_of(projects)
    found = projects.map { |project| stake_for(project) }

    Aggregate.new(project_count: found.size, contributed_cents: found.sum(&:contributed_cents),
                  attributed_reach: found.sum(&:attributed_reach))
  end
end
