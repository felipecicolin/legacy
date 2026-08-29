# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  # Fechado por padrão: todo controller exige sessão, e quem abre uma action ao
  # público diz isso explicitamente com `allow_unauthenticated_access`. O
  # inverso — abrir tudo e lembrar de fechar — erra calado, e o erro é uma
  # página autenticada servida a quem não entrou.
  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**)
      skip_before_action :require_authentication, **
    end
  end

  private

  def authenticated?
    resume_session
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  # O cookie guarda o id de uma linha em `sessions`, e não o id do usuário: é o
  # que permite encerrar a sessão no servidor.
  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_path
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
    end
  end

  def terminate_session
    Current.session.destroy!
    cookies.delete(:session_id)
  end
end
