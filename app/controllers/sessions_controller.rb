# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  # Entrar e sair não agem sobre registro de ninguém: a sessão é do navegador.
  skip_authorization_for

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new; end

  # Uma única mensagem para senha errada e para e-mail inexistente, de
  # propósito: distinguir as duas entrega ao atacante a lista de quem tem
  # conta. O tempo de resposta também não distingue — o `authenticate_by` do
  # Active Record calcula um digest descartável no ramo em que não achou
  # ninguém, justamente para o custo do bcrypt aparecer nos dois casos.
  def create
    user = User.authenticate_by(params.permit(:email_address, :password))
    return redirect_to(new_session_path, alert: t(".failed")) unless user

    start_new_session_for user
    redirect_to after_authentication_url
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
