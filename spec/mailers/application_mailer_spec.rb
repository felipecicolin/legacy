# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMailer do
  it "sets a default sender" do
    expect(described_class.default[:from]).to eq("from@example.com")
  end

  it "renders every mail through the mailer layout" do
    expect(described_class._layout).to eq("mailer")
  end
end
