# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharePercentage do
  it "returns zero when the target is zero" do
    expect(described_class.call(10, 0)).to eq(0)
  end

  it "returns a bounded rounded percentage" do
    expect(described_class.call(25, 40)).to eq(63)
    expect(described_class.call(150, 100)).to eq(100)
    expect(described_class.call(-10, 100)).to eq(0)
  end
end
