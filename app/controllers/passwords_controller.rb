# frozen_string_literal: true

class PasswordsController < ApplicationController
  allow_unauthenticated_access

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_password_path, alert: t("passwords.rate_limited") }

  def new; end

  def edit
    return if reset_user

    redirect_to new_password_path, alert: t("passwords.invalid_token")
  end

  # A resposta é a mesma exista ou não a conta — mesma mensagem, mesma rota.
  # Confirmar "este e-mail não está cadastrado" transformaria a recuperação de
  # senha num verificador de contas aberto ao público.
  def create
    user = User.find_by(email_address: params[:email_address])
    PasswordsMailer.reset(user).deliver_later if user
    redirect_to new_session_path, notice: t(".sent")
  end

  def update
    user = reset_user
    return redirect_to(new_password_path, alert: t("passwords.invalid_token")) unless user

    save_new_password(user)
  end

  private

  # Sem ivar em `before_action`: o token é lido onde é usado. Guardar o usuário
  # num `@user` entre um filtro e duas actions é o que faz o reek acusar
  # `InstanceVariableAssumption`, e ele está certo — o estado fica implícito.
  #
  # A versão sem `!` devolve nil no token inválido, expirado ou já usado. A
  # com `!` levanta `InvalidSignature`, e transformar exceção em redirect é
  # trabalho que o retorno nil já entrega.
  def reset_user
    User.find_by_password_reset_token(params[:token])
  end

  def save_new_password(user)
    unless user.update(params.permit(:password, :password_confirmation))
      return redirect_to(edit_password_path(params[:token]), alert: t("passwords.update.mismatch"))
    end

    # Trocar a senha derruba toda sessão aberta: se a troca veio de uma conta
    # comprometida, quem estava dentro não continua dentro.
    user.sessions.destroy_all
    redirect_to new_session_path, notice: t("passwords.update.updated")
  end
end
