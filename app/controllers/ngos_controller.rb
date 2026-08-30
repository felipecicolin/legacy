# frozen_string_literal: true

class NgosController < ApplicationController
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
    ngo = policy_scope(Ngo).find_by!(slug: params.expect(:id))
    authorize ngo

    render :show, locals: { ngo: ngo, presenter: presenter_for(ngo) }
  end

  private

  def presenter_for(ngo)
    NgoPresenter.new(ngo, pundit_user.visibility)
  end
end
