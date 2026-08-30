# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin fundraising dashboard" do
  let(:password) { "s3nha-de-teste-longa" }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: }
  end

  it "renders the simulated fundraising dashboard for staff" do
    user = create(:user, password:)
    create(:staff_role, :admin, user:)
    sign_in(user)

    get admin_fundraising_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Painel de arrecadação")
    expect(response.body).to include("DADOS SIMULADOS")
  end

  it "keeps the dashboard closed to authenticated non-staff users" do
    sign_in(create(:user, password:))

    get admin_fundraising_path

    expect(response).to have_http_status(:forbidden)
  end
end
