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
    Current.session ||= find_session_by_cookie || resume_demo_session
  end

  # Login automático de DEMONSTRAÇÃO. Ligado só quando `DEMO_USER_EMAIL` existe
  # no ambiente, e essa é a trava: fora dela o comportamento é o de sempre, e
  # nem teste nem desenvolvimento herdam a porta aberta por acidente.
  #
  # O que isto faz é sério e vale escrito: enquanto a variável estiver posta, a
  # aplicação INTEIRA responde como aquela pessoa a qualquer visitante da URL —
  # inclusive o alcance de plataforma que a conta tiver. Aponte-a para uma
  # conta sem `StaffRole`, ou a vitrine passa a servir o que a sensibilidade
  # existe para esconder. Ver docs/authentication.md.
  def resume_demo_session
    email = ENV.fetch("DEMO_USER_EMAIL", nil)
    return if email.blank?

    user = User.find_by(email_address: email)
    start_new_session_for(user) if user
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
