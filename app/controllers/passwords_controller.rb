# frozen_string_literal: true

class PasswordsController < ApplicationController
  # Fora do AppShellComponent: o shell é a moldura de quem já entrou, e
  # quem chega aqui não tem para onde navegar. Ver docs/design-system/auth-layout.md.
  layout "authentication"

  allow_unauthenticated_access

  # Recuperação de senha é para quem não conseguiu entrar — não há contexto
  # autenticado, e o token no lugar do id é o que faz as vezes de autorização.
  skip_authorization_for

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_password_path, alert: t("passwords.rate_limited") }

  def new
    authorize_public_page
  end

  def edit
    authorize_public_page
    return if reset_user

    redirect_to new_password_path, alert: t("passwords.invalid_token")
  end

  # A resposta é a mesma exista ou não a conta — mesma mensagem, mesma rota.
  # Confirmar "este e-mail não está cadastrado" transformaria a recuperação de
  # senha num verificador de contas aberto ao público.
  def create
    authorize_public_page
    user = User.find_by(email_address: params.expect(:email_address))
    PasswordsMailer.reset(user).deliver_later if user
    flash[:notice] = t(".sent")
    render_flash(new_session_path)
  end

  # Todo redirect daqui responde a um PUT, e por isso vai com 303. Num 302 o
  # fetch só troca o método para GET quando o original era POST — num PUT ele
  # preserva, e o Turbo reemitiria PUT para o destino, onde não há rota.
  def update
    authorize_public_page
    user = reset_user
    return redirect_to(new_password_path, status: :see_other, alert: t("passwords.invalid_token")) unless user

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
    User.find_by_password_reset_token(params.expect(:token))
  end

  def save_new_password(user)
    password, confirmation = params.expect(:password, :password_confirmation)
    unless user.update(password:, password_confirmation: confirmation)
      return redirect_to(edit_password_path(params[:token]), status: :see_other,
                                                             alert: password_error_for(user))
    end

    # Trocar a senha derruba toda sessão aberta: se a troca veio de uma conta
    # comprometida, quem estava dentro não continua dentro.
    user.sessions.destroy_all
    redirect_to new_session_path, status: :see_other, notice: t("passwords.update.updated")
  end

  # O `has_secure_password` reprova por mais de um motivo: confirmação
  # divergente, senha em branco, senha acima dos 72 bytes do bcrypt. Dizer "as
  # senhas não conferem" nos três manda a pessoa procurar o erro onde ele não
  # está — e o `maxlength` da view é validação de navegador, que um POST direto
  # não encontra.
  def password_error_for(user)
    return t("passwords.update.mismatch") if user.errors.of_kind?(:password_confirmation, :confirmation)

    t("passwords.update.invalid")
  end
end
