# frozen_string_literal: true

require "rails_helper"

RSpec.describe CredentialPolicy do
  let(:owner) { create(:user) }
  let(:owner_profile) { create(:profile, user: owner) }
  let(:credential) { create(:credential, profile: owner_profile) }

  def context_for(user) = Authorization::Context.for(user.reload)

  def policy_for(user) = described_class.new(context_for(user), credential)

  it "shows the document to the person it belongs to" do
    owner_profile

    expect(policy_for(owner).show?).to be(true)
  end

  it "hides the document from another person" do
    stranger = create(:user)
    create(:profile, user: stranger)

    expect(policy_for(stranger).show?).to be(false)
  end

  # A pessoa sem perfil é o caso que um `record.profile_id == context.profile.id`
  # ingênuo quebraria com NoMethodError em vez de recusar.
  it "hides the document from a user without a profile" do
    expect(policy_for(create(:user)).show?).to be(false)
  end

  it "hides the document from an anonymous reader" do
    expect(described_class.new(Authorization::Context.anonymous, credential).show?).to be(false)
  end

  it "shows the document to who verifies professional registration, and to nobody else on the team" do
    permissions = %i[support curator admin].map do |staff_level|
      verifier = create(:user).tap { |user| create(:staff_role, user: user, staff_level: staff_level) }
      policy_for(verifier).show?
    end

    expect(permissions).to eq([false, true, true])
  end
end
