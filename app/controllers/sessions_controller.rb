# frozen_string_literal: true

class SessionsController < ApplicationController
  # Fora do AppShellComponent: o shell é a moldura de quem já entrou, e
  # quem chega aqui não tem para onde navegar. Ver docs/design-system/auth-layout.md.
  layout "authentication"

  allow_unauthenticated_access only: %i[new create]

  # Entrar e sair não agem sobre registro de ninguém: a sessão é do navegador.
  skip_authorization_for

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new
    authorize_public_page
  end

  # Uma única mensagem para senha errada e para e-mail inexistente, de
  # propósito: distinguir as duas entrega ao atacante a lista de quem tem
  # conta. O tempo de resposta também não distingue — o `authenticate_by` do
  # Active Record calcula um digest descartável no ramo em que não achou
  # ninguém, justamente para o custo do bcrypt aparecer nos dois casos.
  def create
    authorize_public_page
    email_address, password = params.expect(:email_address, :password)
    user = User.authenticate_by(email_address:, password:)
    return redirect_to(new_session_path, alert: t(".failed")) unless user

    start_new_session_for user
    redirect_to after_authentication_url
  end

  def destroy
    authorize_page
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
