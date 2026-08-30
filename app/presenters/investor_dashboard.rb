# frozen_string_literal: true

# A visão do investidor: quanto ele aportou, em que obras isso entrou, quantas
# pessoas essa fatia alcança por ano, e o multiplicador que resume as duas
# coisas. Ver docs/investor-dashboard.md.
#
# "Em quais obras" mora no `FundedProjects`: a pergunta tem estado próprio —
# o que é visível, o que virou agregado — e mantê-la aqui fazia deste painel
# duas classes empilhadas numa.
class InvestorDashboard
  # Base do multiplicador. "Cada R$ 1.000 alcançam 47 pessoas por ano" se lê;
  # "0,047 pessoas por real" é o mesmo número e não se lê.
  MULTIPLIER_BASE_CENTS = 100_000

  # Horizonte da projeção de alcance acumulado. Ver `projected_reach`.
  PROJECTION_YEARS = 5

  def initialize(profile, context)
    @profile = profile
    @context = context
  end

  delegate :visibility, to: :@context
  delegate :stakes, :active_stakes, :hidden, :hidden_disclosable?, :hidden_withheld?, to: :funded

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
  def unlinked_cents = invested_cents - funded.contributed_in_projects_cents

  def people_reached
    active_stakes.sum(&:attributed_reach) + funded.disclosable(:attributed_reach)
  end

  def active_count = active_stakes.size + funded.disclosable(:project_count)

  # O denominador é o que ENTROU EM OBRA, não o total aportado: dinheiro sem
  # obra vinculada não tem alcance para dividir, e mantê-lo embaixo faria o
  # multiplicador cair sem que obra nenhuma tivesse mudado.
  # Quanto custou cada pessoa alcançada num ano. É o inverso do multiplicador e
  # a leitura que responde "meu real rende bem aqui?" — a única forma de ROI
  # social que sai EXATA do que existe: dinheiro que entrou em obra dividido
  # pelo alcance atribuído a ele.
  def cost_per_person_cents
    return if people_reached.zero?

    reach_denominator_cents / people_reached
  end

  # Projeção, não medição. Cinco anos é ASSUNÇÃO: a obra não guarda vida útil,
  # e sem essa coluna qualquer horizonte é escolha de quem desenha a tela. Por
  # isso o horizonte vai impresso ao lado do número — projeção sem premissa à
  # vista é chute com aparência de dado.
  def projected_reach = people_reached * PROJECTION_YEARS

  def people_per_base
    return if reach_denominator_cents.zero?

    people_reached * MULTIPLIER_BASE_CENTS / reach_denominator_cents
  end

  private

  def funded
    @funded ||= FundedProjects.new(contributions, visibility)
  end

  def reach_denominator_cents
    active_stakes.sum(&:contributed_cents) + funded.disclosable(:contributed_cents)
  end
end
