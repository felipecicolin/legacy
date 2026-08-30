# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Fechado por padrão, pela mesma razão da autenticação: toda action passa por
  # `authorize`, e quem não tem registro para autorizar diz isso explicitamente.
  # O inverso — confiar em quem lembrar de chamar — erra calado, e o erro é uma
  # action servindo dado de outra pessoa. Ver docs/authorization.md.
  after_action :verify_authorized

  # As duas exceções respondem igual, e é essa igualdade que é a regra: se
  # "não existe" fosse distinguível de "não pode ver", a rota viraria oráculo —
  # bastava varrer ids e ver qual respondia diferente para enumerar o que a
  # política de sensibilidade esconde.
  rescue_from Pundit::NotAuthorizedError, ActiveRecord::RecordNotFound,
              with: :deny_without_confirming

  # As actions de autenticação e a raiz não têm registro para autorizar. Não é
  # atalho: o formulário de login existe justamente para quem ainda não é
  # ninguém, e não há objeto sobre o qual perguntar.
  def self.skip_authorization_for(**)
    skip_after_action :verify_authorized, **
  end

  private

  # As policies recebem o contexto, não o `User`: papel de plataforma e
  # vínculos aceitos são resolvidos uma vez por request, e o contexto anônimo é
  # representável — o que deixa a mesma policy responder a quem não entrou.
  #
  # `authenticated?` é chamado pelo efeito: ele resume a sessão do cookie. Num
  # controller que exige login isso já aconteceu no `before_action`; num que
  # abra a action ao público e ainda assim autorize, é esta linha que faz o
  # leitor autenticado ser reconhecido em vez de tratado como anônimo. Sem ela,
  # `Current.session` continuaria vazia e a policy responderia a pergunta
  # errada — em silêncio, porque a tela renderiza igual.
  def pundit_user
    authenticated?
    Authorization::Context.for(Current.user)
  end

  # 404, e não 403. Um 403 confirma que o recurso existe, e para uma obra
  # confidencial a existência já é a informação que a política protege: daria
  # para enumerar ids até achar o que está escondido. É a mesma escolha do
  # login, que não diz se a conta existe, e a da entrega de blob.
  def deny_without_confirming
    head :not_found
  end
end
