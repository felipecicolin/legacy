# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passwords" do
  let!(:user) { create(:user, email_address: "fulano@ex.com") }
  let(:token) { user.password_reset_token }

  describe "GET /passwords/new" do
    it "renders the request form" do
      get new_password_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /passwords" do
    it "sends the reset mail for an account that exists" do
      expect { post passwords_path, params: { email_address: user.email_address } }
        .to have_enqueued_mail(PasswordsMailer, :reset)
    end

    it "sends nothing for an address with no account" do
      expect { post passwords_path, params: { email_address: "ninguem@ex.com" } }
        .not_to have_enqueued_mail(PasswordsMailer, :reset)
    end

    # A recuperação de senha não pode virar verificador de contas: a resposta
    # é a mesma exista ou não o e-mail.
    it "answers an unknown address exactly as it answers a known one" do
      post passwords_path, params: { email_address: user.email_address }
      known = [response.status, response.location, flash[:notice]]

      post passwords_path, params: { email_address: "ninguem@ex.com" }

      expect([response.status, response.location, flash[:notice]]).to eq(known)
    end

    it "blocks the eleventh request within the window" do
      10.times { post passwords_path, params: { email_address: user.email_address } }

      post passwords_path, params: { email_address: user.email_address }

      expect(flash[:alert]).to eq(I18n.t("passwords.rate_limited"))
    end
  end

  describe "GET /passwords/:token/edit" do
    it "renders the form for a valid token" do
      get edit_password_path(token)

      expect(response).to have_http_status(:ok)
    end

    it "turns a garbage token away" do
      get edit_password_path("nao-e-um-token")

      expect(response).to redirect_to(new_password_path)
    end

    it "turns an expired token away" do
      expired = token

      travel 16.minutes do
        get edit_password_path(expired)
      end

      expect(flash[:alert]).to eq(I18n.t("passwords.invalid_token"))
    end
  end

  describe "PATCH /passwords/:token" do
    def submit(nova: "s3nha-nova-longa", confirmacao: "s3nha-nova-longa", com: token)
      patch password_path(com), params: { password: nova, password_confirmation: confirmacao }
    end

    it "changes the password" do
      submit

      expect(user.reload.authenticate("s3nha-nova-longa")).to be_truthy
    end

    # Trocar a senha derruba toda sessão aberta: se a troca veio de uma conta
    # comprometida, quem estava dentro não continua dentro.
    it "destroys every open session" do
      user.sessions.create!

      expect { submit }.to change(Session, :count).by(-1)
    end

    # 303, e não o 302 do `redirect_to`: um 302 só vira GET quando o pedido era
    # POST. Num PUT o fetch preserva o método, e o Turbo reemitiria PUT para
    # `new_session_path`, onde `resource :session` não declara essa rota.
    it "answers the PUT with See Other, so the browser follows it as a GET" do
      submit

      expect(response).to have_http_status(:see_other)
    end

    it "refuses a confirmation that does not match" do
      submit(confirmacao: "outra-coisa")

      expect(flash[:alert]).to eq(I18n.t("passwords.update.mismatch"))
    end

    # O `maxlength: 72` da view é validação de navegador. Um pedido direto passa
    # por ela, e antes desta correção a resposta dizia "as senhas não conferem"
    # sobre duas senhas idênticas.
    it "says what is actually wrong when the password is too long" do
      longa = "x" * 100

      submit(nova: longa, confirmacao: longa)

      expect(flash[:alert]).to eq(I18n.t("passwords.update.invalid"))
    end

    it "refuses an invalid token" do
      submit(com: "nao-e-um-token")

      expect(response).to redirect_to(new_password_path)
    end

    # O token carrega o digest da senha, então trocá-la invalida o próprio
    # link — o mesmo e-mail não serve para uma segunda troca.
    it "refuses a token that was already spent" do
      spent = token
      submit(com: spent)

      submit(nova: "terceira-s3nha-longa", confirmacao: "terceira-s3nha-longa", com: spent)

      expect(flash[:alert]).to eq(I18n.t("passwords.invalid_token"))
    end
  end
end
