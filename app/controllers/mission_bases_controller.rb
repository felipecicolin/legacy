# frozen_string_literal: true

class MissionBasesController < ApplicationController
  allow_unauthenticated_access

  def index
    authorize_public_page
    render_placeholder
  end

  # `authorize` sobre o REGISTRO, e não só sobre a página: uma base fora do
  # alcance do leitor responde 404 igual a uma que não existe. Ver
  # docs/authorization.md.
  #
  # `locals:` em vez de variável de instância. A view declara o que recebe com
  # locais estritos, e o que ela não recebe não está lá para ser lido por
  # engano — que é o que uma ivar esquecida vira: `nil` em silêncio.
  def show
    mission_base = policy_scope(MissionBase).find_by!(slug: params.expect(:id))
    authorize mission_base

    render :show, locals: { mission_base: mission_base, presenter: presenter_for(mission_base) }
  end

  private

  def presenter_for(mission_base)
    MissionBasePresenter.new(mission_base, pundit_user.visibility)
  end
end
