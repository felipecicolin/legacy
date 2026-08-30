# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions" do
  let(:password) { "s3nha-de-teste-longa" }
  let!(:user) { create(:user, email_address: "fulano@ex.com", password: password) }

  def sign_in(email: user.email_address, senha: password)
    post session_path, params: { email_address: email, password: senha }
  end

  describe "GET /session/new" do
    it "renders the sign-in form" do
      get new_session_path

      expect(response).to have_http_status(:ok)
    end

    # A tela de acesso não passa pelo AppShellComponent, e trocar de layout é
    # o tipo de mudança que leva junto o que o layout antigo dava de graça.
    it "renders the split layout instead of the application shell" do
      get new_session_path

      expect(response.body).to include("main-content")
      expect(response.body).not_to include("app-shell-drawer")
    end
  end

  describe "POST /session" do
    it "creates a server-side session and lands on the root page" do
      expect { sign_in }.to change(user.sessions, :count).by(1)

      expect(response).to redirect_to(root_url)
    end

    it "returns to the page that demanded authentication" do
      get root_path

      sign_in

      expect(response).to redirect_to(root_url)
    end

    it "authenticates despite different case and surrounding whitespace" do
      sign_in(email: "  Fulano@Ex.COM ")

      expect(response).to redirect_to(root_url)
    end

    it "refuses the wrong password without opening a session" do
      expect { sign_in(senha: "s3nha-errada") }.not_to change(Session, :count)

      expect(response).to redirect_to(new_session_path)
    end

    # `flash[:alert]` preenchido e toast ausente é exatamente o que um layout
    # sem o partial de flash produz: a pessoa erra a senha, volta para o mesmo
    # formulário e nada explica o porquê.
    it "shows the failure on the page it redirects to" do
      sign_in(senha: "s3nha-errada")

      follow_redirect!

      expect(response.body).to include(I18n.t("sessions.create.failed"))
    end

    # Enumeração de usuário: se "senha errada" e "e-mail não existe" tiverem
    # respostas distinguíveis, o formulário de login vira um verificador de
    # contas. O tempo também não distingue — o `authenticate_by` calcula um
    # digest descartável no ramo em que não encontrou ninguém.
    it "answers an unknown email exactly as it answers a wrong password" do
      sign_in(senha: "s3nha-errada")
      wrong_password = [response.status, response.location, flash[:alert]]

      sign_in(email: "ninguem@ex.com", senha: "s3nha-errada")

      expect([response.status, response.location, flash[:alert]]).to eq(wrong_password)
    end

    it "keeps the password out of the logged parameters" do
      sign_in

      expect(request.filtered_parameters["password"]).to eq("[FILTERED]")
    end

    it "blocks the eleventh attempt within the window" do
      10.times { sign_in(senha: "s3nha-errada") }

      sign_in(senha: "s3nha-errada")

      expect(flash[:alert]).to eq(I18n.t("sessions.rate_limited"))
    end
  end

  describe "DELETE /session" do
    it "destroys the session on the server, so replaying the cookie fails" do
      sign_in
      cookie = response.cookies["session_id"]

      expect { delete session_path }.to change(Session, :count).by(-1)

      cookies[:session_id] = cookie
      get root_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
