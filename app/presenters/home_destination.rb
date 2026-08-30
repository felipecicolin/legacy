# frozen_string_literal: true

# Decide o destino da raiz autenticada sem transformar o controller em regra de
# domínio: quem trabalha em uma obra começa no painel da equipe; as demais
# pessoas começam no painel de aportes.
class HomeDestination
  def initialize(user)
    @user = user
  end

  def on_a_team?
    profile = @user.profile
    profile && profile.project_participations.effective.exists?
  end
end
