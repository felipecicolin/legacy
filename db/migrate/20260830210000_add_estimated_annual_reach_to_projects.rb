# frozen_string_literal: true

# Quantas pessoas a obra estima alcançar por ano. É o número que a dash do
# investidor multiplica pela fatia que ele financiou — sem ele, "pessoas
# alcançadas" não tem de onde sair. Ver docs/investor-dashboard.md.
#
# Não dá para reaproveitar `ngos.people_served`: ele é da ONG inteira e não tem
# dimensão de tempo, então somá-lo pelas obras de uma mesma ONG contaria as
# mesmas pessoas várias vezes.
#
# Nulável de propósito: obra em levantamento ainda não tem a estimativa, e um
# zero mentiria dizendo que ela alcança ninguém.
class AddEstimatedAnnualReachToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :estimated_annual_reach, :integer

    add_check_constraint :projects, "estimated_annual_reach is null or estimated_annual_reach >= 0",
                         name: "projects_estimated_annual_reach_not_negative"
  end
end
