# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Credential documents" do
  let(:password) { "s3nha-de-teste-longa" }
  let!(:owner) { create(:user, password: password) }
  let!(:profile) { create(:profile, user: owner) }
  let!(:credential) { create(:credential, profile: profile) }

  before do
    credential.document.attach(io: StringIO.new("documento reservado"), filename: "registro.pdf",
                               content_type: "application/pdf")
    credential.save!
  end

  def sign_in(user, password: "s3nha-de-teste-longa")
    post session_path, params: { email_address: user.email_address, password: password }
  end

  it "requires authentication before serving the document" do
    get document_credential_path(credential)

    expect(response).to redirect_to(new_session_path)
  end

  it "serves the document as a download to its profile owner" do
    sign_in(owner, password: password)

    get document_credential_path(credential)

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("documento reservado")
    expect(response.headers["Content-Disposition"]).to start_with("attachment")
  end

  it "returns not found when the credential has no document" do
    credential_without_document = create(:credential, profile: profile)

    sign_in(owner, password: password)

    get document_credential_path(credential_without_document)

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found to another authenticated user" do
    other_user = create(:user, password: password)
    create(:profile, user: other_user)
    sign_in(other_user, password: password)

    get document_credential_path(credential)

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("documento reservado")
  end

  it "returns not found for an unguessable credential id" do
    sign_in(owner, password: password)

    get document_credential_path(id: "nao-existe")

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found to an authenticated user without a profile" do
    user_without_profile = create(:user, password: password)
    sign_in(user_without_profile, password: password)

    get document_credential_path(credential)

    expect(response).to have_http_status(:not_found)
  end

  # Quem verifica registro profissional precisa LER o documento — é a própria
  # verificação. O controller busca a credencial sem filtro e deixa a policy
  # decidir; quem entrega este alcance é o nível `curator`.
  it "serves the document to who verifies professional registration" do
    curator = create(:user, password: password)
    create(:staff_role, :curator, user: curator)
    sign_in(curator, password: password)

    get document_credential_path(credential)

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("documento reservado")
  end

  # `support` é da equipe e mesmo assim não alcança: ser staff não é o critério.
  it "returns not found to a support staff" do
    support = create(:user, password: password)
    create(:staff_role, user: support)
    sign_in(support, password: password)

    get document_credential_path(credential)

    expect(response).to have_http_status(:not_found)
  end
end
