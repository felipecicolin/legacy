# frozen_string_literal: true

class ApplicationController < ActionController::Base
  PAGE_AUTHORIZATION_QUERIES = %w[access? staff_access? public_access?].freeze

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
  rescue_from ActiveRecord::RecordNotFound, with: :deny_without_confirming
  rescue_from Pundit::NotAuthorizedError, with: :render_authorization_error
  rescue_from ActionController::ParameterMissing, with: :render_unprocessable_entity

  # As actions de autenticação e a raiz não têm registro para autorizar. Não é
  # atalho: o formulário de login existe justamente para quem ainda não é
  # ninguém, e não há objeto sobre o qual perguntar.
  def self.skip_authorization_for(**)
    skip_after_action :verify_authorized, **
  end

  protected

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

  def authorize_page
    authorize :page, :access?, policy_class: ApplicationPolicy
  end

  def authorize_public_page
    authorize :page, :public_access?, policy_class: ApplicationPolicy
  end

  def authorize_staff_page
    authorize :page, :staff_access?, policy_class: ApplicationPolicy
  end

  def render_placeholder
    render template: "shared/placeholder"
  end

  def render_flash(path = root_path)
    respond_to do |format|
      format.html { redirect_to path }
      format.turbo_stream { render partial: "shared/flash", formats: [:turbo_stream] }
    end
  end

  def render_authorization_error(error)
    return render_error(:forbidden, :forbidden) if PAGE_AUTHORIZATION_QUERIES.include?(error.query.to_s)

    render_not_found
  end

  def render_not_found
    render_error(:not_found, :not_found)
  end

  def render_unprocessable_entity
    render_error(:unprocessable_entity, :unprocessable_entity)
  end

  def render_error(template, status)
    render template: "errors/#{template}", status:, layout: "application"
  end

  # 404, e não 403. Um 403 confirma que o recurso existe, e para uma obra
  # confidencial a existência já é a informação que a política protege: daria
  # para enumerar ids até achar o que está escondido. É a mesma escolha do
  # login, que não diz se a conta existe, e a da entrega de blob.
  def deny_without_confirming
    head :not_found
  end
end
