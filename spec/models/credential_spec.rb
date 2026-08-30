# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credential do
  subject(:credential) { build(:credential) }

  it { is_expected.to belong_to(:profile) }
  it { is_expected.to have_one_attached(:document) }
  it { is_expected.to validate_presence_of(:kind) }
  it { is_expected.to validate_presence_of(:number) }
  it { is_expected.to validate_presence_of(:issuing_body) }
  it { is_expected.to validate_presence_of(:verification_status) }

  it "starts pending when no verification status is supplied" do
    expect(credential.verification_status).to eq("pending")
  end

  describe "#valid_for_professional_registration?" do
    it "blocks a pending credential" do
      expect(credential).not_to be_valid_for_professional_registration
    end

    it "accepts a verified credential that has not expired" do
      credential.verification_status = :verified

      expect(credential).to be_valid_for_professional_registration
    end

    it "blocks a verified credential whose expiration date has passed" do
      credential.assign_attributes(verification_status: :verified, expires_on: Date.current)

      expect(credential).not_to be_valid_for_professional_registration
    end

    it "blocks a verified credential without an expiration date" do
      credential.assign_attributes(verification_status: :verified, expires_on: nil)

      expect(credential).not_to be_valid_for_professional_registration
    end

    it "blocks a rejected credential even when its date is current" do
      credential.verification_status = :rejected

      expect(credential).not_to be_valid_for_professional_registration
    end
  end

  it "removes its verification document when destroyed" do
    credential = create(:credential)
    credential.document.attach(io: StringIO.new("documento"), filename: "registro.pdf",
                               content_type: "application/pdf")
    credential.save!

    expect { credential.destroy! }.to change(ActiveStorage::Attachment, :count).by(-1)
  end
end
