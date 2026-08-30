# frozen_string_literal: true

# O dinheiro de uma obra: quanto ela estima alcançar por real, o que foi
# orçado, o que foi gasto e o que foi arrecadado.
#
# Concern e não métodos soltos no `Project` por duas razões que se somam: a
# classe já respondia por estado, transição e sensibilidade, e estes quatro
# formam um assunto próprio — quem edita orçamento não mexe em transição de
# estado. Ver docs/team-dashboard.md e docs/investor-dashboard.md.
module ProjectAccounting
  extend ActiveSupport::Concern

  # Quanto do alcance anual desta obra corresponde a uma fatia financiada.
  # Mora na obra, e não no painel do investidor, porque quem sabe a meta e a
  # estimativa é ela.
  def reach_for(contributed_cents)
    return 0 if funding_target_cents.zero? || estimated_annual_reach.blank?

    estimated_annual_reach * contributed_cents / funding_target_cents
  end

  # Os quatro números que o painel do time lê de uma obra. Juntos aqui porque
  # quem sabe orçar, gastar e arrecadar é a obra — o painel só arruma na tela.
  def budget_figures
    { budgeted_cents: current_budget&.total_cents.to_i, spent_cents: spent_cents,
      raised_cents: campaigns.sum(:raised_cents), goal_cents: campaigns.sum(:goal_cents) }
  end

  private

  # O aprovado é o que vale; sem ele, o rascunho mais recente é o que o time
  # está montando, e mostrar zero esconderia o trabalho em curso.
  def current_budget
    budgets.approved.order(version: :desc).first || budgets.order(version: :desc).first
  end

  # Despesa recusada não saiu do caixa, e somá-la inflaria a execução.
  def spent_cents
    expenses.where.not(status: :rejected).sum(:amount_cents)
  end
end
