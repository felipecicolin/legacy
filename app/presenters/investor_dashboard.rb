# frozen_string_literal: true

# A visão do investidor: quanto ele aportou, em que obras isso entrou, quantas
# pessoas essa fatia alcança por ano, e o multiplicador que resume as duas
# coisas. Ver docs/investor-dashboard.md.
class InvestorDashboard
  # Uma obra financiada, já com a fatia deste investidor calculada. Objeto de
  # valor e não hash: a view lê `stake.attributed_reach`, e um `[:reach]` que
  # some vira `nil` na tela em vez de erro.
  Stake = Data.define(:project, :contributed_cents, :attributed_reach)

  # O que sobra quando as obras não podem ser detalhadas: contagem, dinheiro e
  # alcance, sem nome, sem ONG e sem lugar.
  Aggregate = Data.define(:count, :contributed_cents, :attributed_reach)

  # Mesmo piso do agregado de campanha. O repositório tem UM número para
  # "quantos itens são poucos demais para anonimizar", e um segundo divergiria
  # do primeiro na primeira vez que alguém mexesse em um deles.
  MINIMUM_AGGREGATE_COUNT = Campaign::MINIMUM_AGGREGATE_COUNT

  # Base do multiplicador. "Cada R$ 1.000 alcançam 47 pessoas por ano" se lê;
  # "0,047 pessoas por real" é o mesmo número e não se lê.
  MULTIPLIER_BASE_CENTS = 100_000

  def initialize(profile, context)
    @profile = profile
    @context = context
  end

  delegate :visibility, to: :@context

  def investor? = contributions.exists?

  # `counted` é o escopo do próprio `Contribution` — pendente ou devolvida não
  # é aporte. Reescrever o filtro aqui criaria uma segunda resposta para a
  # mesma pergunta, e é a segunda que diverge.
  def contributions
    @contributions ||= @profile.contributions.counted
  end

  # Sempre exato, inclusive a parte que entrou em obra que ele não alcança: o
  # dinheiro é dele, e esconder o próprio extrato não protege ninguém.
  def invested_cents = contributions.sum(:amount_cents)

  # Aporte que entrou numa campanha sem obra vinculada. É dinheiro real e conta
  # no total, mas não tem obra nem alcance: somá-lo às obras inflaria a conta, e
  # omiti-lo faria os números não fecharem na soma.
  def unlinked_cents = invested_cents - contributed_by_project.values.sum

  def stakes
    @stakes ||= visible_projects.map { |project| stake_for(project) }
  end

  def active_stakes
    @active_stakes ||= stakes.reject { |stake| stake.project.completed? }
  end

  def hidden
    @hidden ||= aggregate_of(funded_projects.hidden_from(visibility).to_a)
  end

  # Abaixo do piso o agregado descreveria quase uma obra só — e como o
  # investidor sabe a que campanha deu, o que sobraria de segredo é exatamente
  # o que a obra confidencial esconde.
  def hidden_disclosable? = hidden.count >= MINIMUM_AGGREGATE_COUNT

  # Obras alcançadas mas não detalháveis e abaixo do piso ficam fora dos
  # números. A tela tem de DIZER isso: número menor sem explicação se lê como
  # número errado.
  def hidden_withheld? = hidden.count.positive? && !hidden_disclosable?

  def people_reached
    active_stakes.sum(&:attributed_reach) + disclosable_hidden(:attributed_reach)
  end

  def active_count = active_stakes.size + disclosable_hidden(:count)

  # O denominador é o que ENTROU EM OBRA, não o total aportado: dinheiro sem
  # obra vinculada não tem alcance para dividir, e mantê-lo embaixo faria o
  # multiplicador cair sem que obra nenhuma tivesse mudado.
  def people_per_base
    return if reach_denominator_cents.zero?

    people_reached * MULTIPLIER_BASE_CENTS / reach_denominator_cents
  end

  private

  def disclosable_hidden(field)
    hidden_disclosable? ? hidden.public_send(field) : 0
  end

  # `{project_id => centavos}`, numa consulta só. O `where.not` é o que separa
  # aporte em obra de aporte na ONG.
  def contributed_by_project
    @contributed_by_project ||=
      contributions.joins(:campaign).where.not(campaigns: { project_id: nil })
                   .group("campaigns.project_id").sum(:amount_cents)
  end

  def funded_projects
    @funded_projects ||= Project.where(id: contributed_by_project.keys)
  end

  def visible_projects
    @visible_projects ||= funded_projects.visible_to(visibility).includes(:ngo).to_a
  end

  def stake_for(project)
    cents = contributed_by_project.fetch(project.id, 0)
    Stake.new(project: project, contributed_cents: cents,
              attributed_reach: attributed_reach(project, cents))
  end

  # Proporcional à fatia financiada, e sobre a META — não sobre o arrecadado.
  # Creditar a obra inteira a cada financiador mostraria as mesmas 15.000
  # pessoas a cinquenta pessoas diferentes; dividir pelo arrecadado encolheria
  # o alcance de quem já deu toda vez que outra pessoa desse.
  def attributed_reach(project, cents)
    target = project.funding_target_cents
    return 0 if target.zero? || project.estimated_annual_reach.blank?

    project.estimated_annual_reach * cents / target
  end

  def aggregate_of(projects)
    hidden_stakes = projects.map { |project| stake_for(project) }

    Aggregate.new(count: hidden_stakes.size,
                  contributed_cents: hidden_stakes.sum(&:contributed_cents),
                  attributed_reach: hidden_stakes.sum(&:attributed_reach))
  end

  def reach_denominator_cents
    active_stakes.sum(&:contributed_cents) + disclosable_hidden(:contributed_cents)
  end
end
