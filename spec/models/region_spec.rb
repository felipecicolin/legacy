# frozen_string_literal: true

require "rails_helper"

RSpec.describe Region do
  it "belongs to a country" do
    expect(build(:region, country: nil)).not_to be_valid
  end

  it "refuses a region without a name" do
    expect(build(:region, name: nil)).not_to be_valid
  end

  it "refuses two regions with the same name in one country" do
    region = create(:region)

    expect(build(:region, country: region.country, name: region.name)).not_to be_valid
  end

  # Nome de subdivisão se repete entre países — há um "Norte" em muitos lugares.
  it "accepts the same name in another country" do
    region = create(:region)

    expect(build(:region, name: region.name)).to be_valid
  end
end
