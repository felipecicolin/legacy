# frozen_string_literal: true

require "rails_helper"

# Entrega de arquivo. O que este arquivo cobra não é uma tela: é que a URL
# pública do Active Storage — a que viaja em print e em e-mail encaminhado —
# não entrega a foto de uma obra que o leitor não alcança.
RSpec.describe "Authorized blobs" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:author) { create(:user) }

  def record_with_photo(**attributes)
    SensitiveTestRecord.create!(name: "Base do Vale", **attributes)
                       .tap { |record| record.photo.attach(GeotaggedPhoto.upload) }
  end

  def sign_in
    user = create(:user)
    post session_path, params: { email_address: user.email_address, password: password }
  end

  def get_blob(record)
    get rails_blob_path(record.photo.blob, only_path: true)
  end

  # A trava que impede a interceptação de rota de se desfazer em silêncio: se o
  # engine voltar a atender estes caminhos, nada mais neste arquivo falha —
  # o Active Storage serve o arquivo e devolve 200 igual.
  it "answers the Active Storage blob path from the authorizing controller" do
    record = record_with_photo

    expect(Rails.application.routes.recognize_path(rails_blob_path(record.photo.blob, only_path: true)))
      .to include(controller: "authorized_blobs", action: "show")
  end

  describe "a confidential record" do
    let(:record) { record_with_photo(sensitivity_level: :confidential) }

    # 404 e não 403: um 403 confirma que o arquivo existe, e a existência de
    # uma foto já é informação sobre a obra.
    it "hides the photo from an anonymous visitor" do
      get_blob(record)

      expect(response).to have_http_status(:not_found)
    end

    # O limite, escrito como exemplo: `confidential` não é alcançável por
    # sessão nenhuma até os papéis chegarem (#20, #21, #31).
    it "hides the photo from someone who is merely signed in" do
      sign_in

      get_blob(record)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "a restricted record" do
    let(:record) { record_with_photo }

    it "hides the photo from an anonymous visitor" do
      get_blob(record)

      expect(response).to have_http_status(:not_found)
    end

    it "serves the photo to someone who is signed in" do
      sign_in

      get_blob(record)

      expect(response).to have_http_status(:ok)
    end

    # Ponta a ponta: o que sai pela rota é o arquivo já limpo, e não o original.
    it "serves the file without the metadata it was uploaded with" do
      sign_in

      get_blob(record)

      expect(response.body).not_to include(GeotaggedPhoto::MARKER)
    end
  end

  describe "a public record" do
    it "serves the photo to an anonymous visitor" do
      record = record_with_photo
      record.promote_visibility!(level: :public, author: author,
                                 justification: "Consentimento da equipe local")

      get_blob(record)

      expect(response).to have_http_status(:ok)
    end
  end

  # O limite do alcance: registro que não declara sensibilidade não é coberto
  # por esta política, e continua sendo servido como o Active Storage sempre
  # serviu. Está escrito em docs/photo-policy.md.
  it "serves an attachment whose record declares no sensitivity" do
    profile = create(:profile)
    profile.avatar.attach(GeotaggedPhoto.upload)

    get rails_blob_path(profile.avatar.blob, only_path: true)

    expect(response).to have_http_status(:ok)
  end

  it "answers a tampered signed id with the same 404" do
    get "/rails/active_storage/blobs/redirect/nao-e-uma-assinatura/base.jpg"

    expect(response).to have_http_status(:not_found)
  end

  describe "variants" do
    def get_variant(record)
      get rails_representation_path(record.photo.variant(resize_to_limit: [48, nil]), only_path: true)
    end

    it "answers the representation path from the authorizing controller" do
      record = record_with_photo
      path = rails_representation_path(record.photo.variant(resize_to_limit: [48, nil]), only_path: true)

      expect(Rails.application.routes.recognize_path(path))
        .to include(controller: "authorized_representations", action: "show")
    end

    it "hides the variant of a confidential record" do
      get_variant(record_with_photo(sensitivity_level: :confidential))

      expect(response).to have_http_status(:not_found)
    end

    it "serves the variant of a restricted record to someone signed in" do
      record = record_with_photo
      sign_in

      get_variant(record)

      expect(response).to have_http_status(:ok)
    end
  end
end
