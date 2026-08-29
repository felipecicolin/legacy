# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper do
  it "is mixed into the view context of every controller" do
    expect(ApplicationController.helpers).to be_a(described_class)
  end
end
