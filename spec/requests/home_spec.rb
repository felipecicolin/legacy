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
end
