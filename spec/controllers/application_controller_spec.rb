# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationController do
  it "is the Action Controller base every controller inherits from" do
    expect(described_class.superclass).to eq(ActionController::Base)
  end

  it "gates the app to modern browsers" do
    expect(described_class).to respond_to(:allow_browser)
  end
end
