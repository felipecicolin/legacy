# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationController do
  let(:app_controller) { described_class.new }

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

  it "authorizes staff pages through the base policy" do
    expect(app_controller).to receive(:authorize).with(:page, :staff_access?, policy_class: ApplicationPolicy)

    app_controller.send(:authorize_staff_page)
  end

  it "hides unauthorized resources as not found" do
    error = Pundit::NotAuthorizedError.new(query: :show?)
    expect(app_controller).to receive(:render_not_found)

    app_controller.send(:render_authorization_error, error)
  end

  it "renders forbidden for an unauthorized page" do
    error = Pundit::NotAuthorizedError.new(query: :access?)
    expect(app_controller).to receive(:render_error).with(:forbidden, :forbidden)

    app_controller.send(:render_authorization_error, error)
  end
end
