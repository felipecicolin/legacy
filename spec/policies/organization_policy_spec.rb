# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrganizationPolicy do
  let(:organization) { create(:organization, organization_status: :approved) }
  let(:pending_organization) { create(:organization, organization_status: :pending) }
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }

  def context_for(user_record) = Authorization::Context.for(user_record.reload)

  def context_with_role(role, on: nil)
    create(:membership, :accepted, profile: profile, organization: on || organization, role: role)
    context_for(user)
  end

  describe "#show?" do
    it "shows an approved organization to anyone, signed in or not" do
      expect(described_class.new(Authorization::Context.anonymous, organization).show?).to be(true)
    end

    it "hides an organization awaiting approval from a stranger" do
      expect(described_class.new(Authorization::Context.anonymous, pending_organization).show?).to be(false)
    end

    it "shows an organization awaiting approval to someone bonded to it" do
      context = context_with_role(:member, on: pending_organization)

      expect(described_class.new(context, pending_organization).show?).to be(true)
    end

    it "shows an organization awaiting approval to the platform team" do
      create(:staff_role, user: user)

      expect(described_class.new(context_for(user), pending_organization).show?).to be(true)
    end
  end

  describe "#create?" do
    it "asks only for a session" do
      aggregate_failures do
        expect(described_class.new(context_for(user), organization).create?).to be(true)
        expect(described_class.new(Authorization::Context.anonymous, organization).create?).to be(false)
      end
    end
  end

  describe "#update?" do
    it "allows the roles that answer for the organization" do
      permissions = %i[owner admin representative member].map do |role|
        described_class.new(context_with_role(role, on: create(:organization)), organization).update?
      end

      expect(permissions).to eq([false, false, false, false])
    end

    it "allows an owner and an admin of this very organization" do
      aggregate_failures do
        expect(described_class.new(context_with_role(:owner), organization).update?).to be(true)
        expect(described_class.new(context_with_role(:admin, on: create(:organization)), organization).update?)
          .to be(false)
      end
    end

    it "allows the platform admin" do
      create(:staff_role, :admin, user: user)

      expect(described_class.new(context_for(user), organization).update?).to be(true)
    end
  end

  describe "#destroy?" do
    it "asks for ownership, not administration" do
      owner = context_with_role(:owner)

      expect(described_class.new(owner, organization).destroy?).to be(true)
    end

    it "refuses an organization admin" do
      admin = context_with_role(:admin)

      expect(described_class.new(admin, organization).destroy?).to be(false)
    end

    it "allows the platform admin" do
      create(:staff_role, :admin, user: user)

      expect(described_class.new(context_for(user), organization).destroy?).to be(true)
    end

    it "refuses a support staff without a bond" do
      create(:staff_role, user: user)

      expect(described_class.new(context_for(user), organization).destroy?).to be(false)
    end
  end
end
