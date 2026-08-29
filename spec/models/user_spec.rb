# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  it { is_expected.to have_many(:sessions).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:email_address) }
  it { is_expected.to validate_presence_of(:password_digest) }

  it "rejects a second account with the same email address" do
    create(:user, email_address: "alguem@exemplo.org")

    expect(build(:user, email_address: "alguem@exemplo.org")).not_to be_valid
  end

  # `normalizes` roda ANTES da validação, e é isso que faz a unicidade da
  # validação e a do índice enxergarem a mesma string.
  it "normalizes case and surrounding whitespace on the email address" do
    user = create(:user, email_address: "  Fulano@Ex.COM ")

    expect(user.email_address).to eq("fulano@ex.com")
  end

  it "treats a differently-cased duplicate as taken" do
    create(:user, email_address: "fulano@ex.com")

    expect(build(:user, email_address: " FULANO@EX.COM ")).not_to be_valid
  end

  it "authenticates with the right password" do
    user = create(:user, password: "s3nha-correta")

    expect(described_class.authenticate_by(email_address: user.email_address,
                                           password: "s3nha-correta")).to eq(user)
  end

  it "refuses the wrong password" do
    user = create(:user, password: "s3nha-correta")

    expect(described_class.authenticate_by(email_address: user.email_address,
                                           password: "s3nha-errada")).to be_nil
  end
end
