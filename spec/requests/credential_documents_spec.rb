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
end
