# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationController do
  it "is the Action Controller base every controller inherits from" do
    expect(described_class.superclass).to eq(ActionController::Base)
  end

  it "gates the app to modern browsers" do
    expect(described_class).to respond_to(:allow_browser)
  end

  # O guarda que faz a autorização ser fechada por padrão. Sem ele, esquecer de
  # chamar `authorize` numa action nova não quebra nada — a tela funciona, e
  # serve dado de outra pessoa. Com ele, o esquecimento levanta em teste.
  it "refuses an action that authorized nothing" do
    controller = Class.new(described_class).new

    expect { controller.send(:verify_authorized) }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end

  it "offers controllers an explicit way out for actions with no record" do
    expect(described_class).to respond_to(:skip_authorization_for)
  end
end
