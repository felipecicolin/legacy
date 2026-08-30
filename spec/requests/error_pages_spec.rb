# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Error pages" do
  around do |example|
    original = Rails.application.config.consider_all_requests_local
    original_detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.config.consider_all_requests_local = false
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    Rails.application.config.consider_all_requests_local = original
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = original_detailed
  end

  it "renders every error page through the application layout" do
    %i[error_not_found error_forbidden error_unprocessable_entity error_internal_server_error].each do |route|
      get public_send("#{route}_path")

      status = route == :error_unprocessable_entity ? 422 : route.to_s.delete_prefix("error_").to_sym
      expect(response).to have_http_status(status)
      expect(response.body).to include("data-simulated=\"true\"")
      expect(response.body).to include("Voltar ao início")
    end
  end

  it "renders the dynamic not found page for an unknown route" do
    get "/rota-que-nao-existe"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Página não encontrada")
  end
end
