# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home" do
  # Fechado por padrão: o `before_action :require_authentication` do concern
  # vale para todo controller, e abrir uma action é uma decisão explícita. O
  # esquecimento erra para o lado que pede login, não para o que vaza.
  it "sends an anonymous visitor to the sign-in page" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "renders for someone who is signed in" do
    user = create(:user)
    post session_path, params: { email_address: user.email_address, password: "s3nha-de-teste-longa" }

    get root_path

    expect(response).to have_http_status(:ok)
  end
end
