# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationRecord do
  it "is abstract, so it never maps to a table of its own" do
    expect(described_class.abstract_class?).to be(true)
  end

  it "sits directly under ActiveRecord::Base" do
    expect(described_class.superclass).to eq(ActiveRecord::Base)
  end
end
