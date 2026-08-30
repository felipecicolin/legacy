# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home" do
  let(:user) { create(:user) }

  def sign_in
    post session_path, params: { email_address: user.email_address, password: "s3nha-de-teste-longa" }
  end

  # Fechado por padrão: o `before_action :require_authentication` do concern
  # vale para todo controller, e abrir uma action é uma decisão explícita. O
  # esquecimento erra para o lado que pede login, não para o que vaza.
  it "sends an anonymous visitor to the sign-in page" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  # A raiz não renderiza nada: ela despacha. Quem não tem obra vai para o
  # painel de quem financia.
  it "sends someone with no project to the investor dashboard" do
    sign_in

    get root_path

    expect(response).to redirect_to(investor_path)
  end

  it "sends someone who works on a project to the team dashboard" do
    create(:project_participation, :active, profile: create(:profile, user: user))
    sign_in

    get root_path

    expect(response).to redirect_to(team_path)
  end

  # A porta aberta da demonstração. Ela é sério: enquanto a variável existe, a
  # aplicação inteira responde como aquela pessoa para qualquer visitante.
  describe "demo auto-login" do
    it "signs an anonymous visitor in as the demo user when one is configured" do
      demo = create(:user, email_address: "demo@exemplo.dev")
      create(:profile, user: demo)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DEMO_USER_EMAIL", nil).and_return(demo.email_address)

      get root_path

      expect(response).to redirect_to(investor_path)
    end

    # Configurar um e-mail que não existe não pode abrir a porta pela metade:
    # sem usuário, o comportamento tem de voltar a ser o de sempre.
    it "still asks for a password when the configured demo user is missing" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DEMO_USER_EMAIL", nil).and_return("ninguem@exemplo.dev")

      get root_path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
