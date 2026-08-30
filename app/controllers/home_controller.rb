# frozen_string_literal: true

# A raiz não tem tela: ela decide para qual painel a pessoa vai.
#
# A ROTA precisa continuar existindo — é nela que o `after_authentication_url`
# cai quando o login não tinha destino guardado, e sem ela um login bem-sucedido
# levanta. O que deixou de existir é a página: um placeholder que dizia "você
# está autenticado" era andaime de quando não havia para onde mandar ninguém.
#
# Sem preferência guardada ainda: quem tem obra cai no painel da obra, porque é
# o de quem tem trabalho hoje; o resto cai no do investidor. Guardar "a última
# usada" pede coluna de preferência, e ela não existe. Ver
# docs/team-dashboard.md.
class HomeController < ApplicationController
  def show
    authorize_page

    redirect_to on_a_team? ? team_path : investor_path
  end

  private

  def on_a_team?
    profile = Current.user.profile

    profile && profile.project_participations.effective.exists?
  end
end
