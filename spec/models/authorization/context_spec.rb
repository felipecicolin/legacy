# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authorization::Context do
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }
  let(:ngo) { create(:ngo) }

  describe ".anonymous" do
    subject(:context) { described_class.anonymous }

    it "represents someone who did not sign in" do
      aggregate_failures do
        expect(context).not_to be_signed_in
        expect(context).not_to be_staff
        expect(context.memberships).to be_empty
      end
    end
  end

  describe ".for" do
    it "answers the anonymous context for a blank user" do
      expect(described_class.for(nil)).to eq(described_class.anonymous)
    end

    context "with a curator staff role" do
      before { create(:staff_role, :curator, user: user) && profile }

      it "carries the profile" do
        expect(described_class.for(user.reload).profile).to eq(profile)
      end

      it "carries the platform role" do
        expect(described_class.for(user.reload).staff_level).to eq(:curator)
      end
    end

    it "answers an empty membership list for a user without a profile" do
      expect(described_class.for(user).memberships).to be_empty
    end

    # Convite pendente é o caso que uma policy distraída trataria como papel.
    it "loads only the accepted memberships" do
      accepted = create(:membership, :accepted, profile: profile, ngo: ngo)
      create(:membership, profile: profile, ngo: create(:ngo))

      expect(described_class.for(user).memberships).to contain_exactly(accepted)
    end
  end

  describe "#role_in" do
    it "answers the role of an accepted membership" do
      create(:membership, :accepted, profile: profile, ngo: ngo, role: :owner)

      expect(described_class.for(user).role_in(ngo)).to eq(:owner)
    end

    it "answers nothing for an ngo the person has no bond with" do
      profile

      expect(described_class.for(user).role_in(ngo)).to be_nil
    end
  end

  describe "#clearance" do
    # O contrato com `Visibility::Context`: ele faz `LEVELS.fetch(clearance)` e
    # levanta em símbolo desconhecido. Todo nível tem de sair daqui utilizável.
    it "resolves to a level the visibility context accepts" do
      levels = [nil, :support, :curator, :admin].map do |staff_level|
        described_class.new(user: user, profile: nil, staff_level: staff_level, memberships: []).clearance
      end

      expect(levels).to eq(%i[restricted restricted restricted confidential])
    end

    it "keeps an anonymous reader at the public level" do
      expect(described_class.anonymous.clearance).to eq(:public)
    end

    it "hands the visibility context its own clearance" do
      create(:staff_role, :admin, user: user)

      expect(described_class.for(user.reload).visibility.allowed_levels)
        .to contain_exactly(:public, :restricted, :confidential)
    end
  end

  describe "#platform_admin?" do
    it "is true only for the admin level" do
      admins = %i[support curator admin].map do |staff_level|
        described_class.new(user: user, profile: nil, staff_level: staff_level, memberships: []).platform_admin?
      end

      expect(admins).to eq([false, false, true])
    end
  end
end
