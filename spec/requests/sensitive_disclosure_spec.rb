# frozen_string_literal: true

require "rails_helper"

# Export e log. O que este arquivo cobra é o resultado, e não a regra que
# alguém lembrou de escrever: uma coluna nova que entre no serializer e carregue
# identificação passa a ser coberta sem ninguém editar o teste.
#
# Vive em `spec/requests/` por dois motivos: o filtro de parâmetro é do log de
# REQUISIÇÃO, e a política não descreve uma classe só.
RSpec.describe "Sensitive disclosure" do
  let(:anonymous) { Visibility::Context.anonymous }
  let(:author) { create(:user) }

  # O `Parameters: {…}` do log não passa por modelo nenhum, então ele é medido
  # sobre o filtro que a aplicação de fato configurou.
  describe "the request log" do
    subject(:filtered) do
      ActiveSupport::ParameterFilter
        .new(Rails.application.config.filter_parameters)
        .filter("profile" => { "legal_name" => "Maria Documento", "display_name" => "Maria S." },
                "field" => { "latitude" => "-22.9", "longitude" => "-43.2", "address" => "Rua 3" })
    end

    it "hides the legal name and every precise location field" do
      expect(filtered.values.flat_map(&:values).tally)
        .to eq({ "[FILTERED]" => 4, "Maria S." => 1 })
    end
  end

  # O nome público NÃO é filtrado de propósito: filtrá-lo esconderia justamente
  # o campo que ajuda a depurar a tela.
  describe "a serialized payload" do
    before do
      SensitiveTestRecord.create!(name: "Base do Vale", code: "CF-01",
                                  sensitivity_level: :confidential)
      SensitiveTestRecord.create!(name: "Base do Rio", code: "RS-01",
                                  latitude: -22.9, longitude: -43.2)
    end

    def payload
      [SensitiveTestRecord.visible_to(anonymous).to_json, Profile.all.to_json].join
    end

    it "carries neither the legal name nor a coordinate of what the reader cannot reach" do
      create(:profile, legal_name: "Maria Documento", display_name: "Maria S.")

      expect(payload).not_to include("Maria Documento", "-22.9", "CF-01", "RS-01")
    end

    it "still carries what the reader is allowed to see" do
      open_base = SensitiveTestRecord.create!(name: "Base Aberta", code: "PB-01")
      open_base.promote_visibility!(level: :public, author: author, justification: "Consentimento")

      expect(payload).to include("PB-01")
    end
  end
end
