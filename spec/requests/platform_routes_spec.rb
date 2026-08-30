# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Platform routes" do
  let(:password) { "s3nha-de-teste-longa" }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: }
  end

  it "uses Portuguese resource paths and the public project code" do
    expect(Rails.application.routes.recognize_path("/obras/OB-0247", method: :get)).to eq(
      controller: "projects", action: "show", code: "OB-0247",
    )
    expect(Rails.application.routes.recognize_path("/bases", method: :get)).to eq(
      controller: "mission_bases", action: "index",
    )
    expect(Rails.application.routes.recognize_path("/campanhas", method: :get)).to eq(
      controller: "campaigns", action: "index",
    )
    expect(Rails.application.routes.recognize_path("/necessidades", method: :get)).to eq(
      controller: "needs", action: "index",
    )
  end

  it "keeps nested resources shallow where appropriate" do
    expect(Rails.application.routes.recognize_path("/progress_reports/7", method: :get)).to eq(
      controller: "progress_reports", action: "show", id: "7",
    )
    expect(Rails.application.routes.recognize_path("/obras/OB-0247/progress_reports", method: :post)).to eq(
      controller: "progress_reports", action: "create", project_code: "OB-0247",
    )
    expect(Rails.application.routes.recognize_path("/necessidades/7/candidacy/new", method: :get)).to eq(
      controller: "candidacies", action: "new", need_id: "7",
    )
  end

  it "exposes the admin dashboard as a namespaced root" do
    expect(Rails.application.routes.recognize_path("/admin", method: :get)).to eq(
      controller: "admin/dashboard", action: "show",
    )
  end

  it "authorizes every resource action before rendering its placeholder" do
    user = create(:user)
    sign_in(user)

    requests = [
      [:get, "/bases"],
      [:get, "/bases/1"],
      [:get, "/bases/1/needs"],
      [:get, "/obras"],
      [:get, "/obras/OB-0247"],
      [:get, "/obras/OB-0247/progress_reports"],
      [:get, "/progress_reports/1"],
      [:get, "/campanhas"],
      [:get, "/campanhas/1"],
      [:get, "/necessidades"],
      [:get, "/necessidades/1"],
      [:get, "/necessidades/1/candidacy/new"],
      [:get, "/search?query=obra"],
    ]

    requests.each { |method, path| public_send(method, path) }

    post "/obras/OB-0247/progress_reports", params: { progress_report: { body: "Atualização" } }
    post "/necessidades/1/candidacy", params: { candidacy: { message: "Posso ajudar" } }

    expect(response).to have_http_status(:ok)
  end

  it "expects declared parameters for write actions" do
    sign_in(create(:user))

    post "/obras/OB-0247/progress_reports", params: {}

    expect(response).to have_http_status(:unprocessable_content)
  end

  # A busca sem termo é a LISTAGEM, e não um pedido malformado: "ver tudo" não
  # é uma tela à parte. O placeholder exigia o termo; a busca de verdade (#51)
  # abre com os filtros e sem ele. Ver docs/search.md.
  it "opens the search with no term at all" do
    get "/search", params: {}

    expect(response).to have_http_status(:ok)
  end

  it "keeps the admin dashboard closed to non-staff users" do
    sign_in(create(:user))

    get admin_root_path

    expect(response).to have_http_status(:forbidden)
  end

  it "allows a staff user into the admin dashboard" do
    user = create(:user)
    create(:staff_role, user:, staff_level: :support)
    sign_in(user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
  end
end
