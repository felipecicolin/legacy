# frozen_string_literal: true

require "rails_helper"

RSpec.describe SensitivityPromotion do
  it "is justified with both an author and a reason" do
    expect(described_class.new(author: build(:user), justification: "Consentimento"))
      .to be_justified
  end

  it "is not justified without an author" do
    expect(described_class.new(author: nil, justification: "Consentimento"))
      .not_to be_justified
  end

  it "is not justified with a blank reason" do
    expect(described_class.new(author: build(:user), justification: " ")).not_to be_justified
  end
end
