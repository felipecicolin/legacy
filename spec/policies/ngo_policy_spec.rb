# frozen_string_literal: true

require "rails_helper"

RSpec.describe NgoPolicy do
  let(:ngo) { create(:ngo, :listed) }
  let(:pending_ngo) { create(:ngo, ngo_status: :pending) }
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }
  let(:context) { Authorization::Context.for(user) }

  def context_for(user_record) = Authorization::Context.for(user_record.reload)

  # Uma pessoa NOVA a cada chamada, de propósito: com um perfil compartilhado
  # entre os exemplos, o papel de `owner` de uma asserção continuava valendo na
  # seguinte, e a policy respondia certo por um vínculo que o exemplo não tinha
  # pedido. O guarda contra isso é o vínculo nascer junto com quem o tem.
  def context_with_role(role, on: nil)
    bearer = create(:user)
    create(:membership, :accepted, profile: create(:profile, user: bearer),
                                   ngo: on || ngo, role: role)
    context_for(bearer)
  end

  describe "#show?" do
    it "shows an approved ngo to anyone, signed in or not" do
      expect(described_class.new(Authorization::Context.anonymous, ngo).show?).to be(true)
    end

    it "hides an ngo awaiting approval from a stranger" do
      expect(described_class.new(Authorization::Context.anonymous, pending_ngo).show?).to be(false)
    end

    it "shows an ngo awaiting approval to someone bonded to it" do
      context = context_with_role(:member, on: pending_ngo)

      expect(described_class.new(context, pending_ngo).show?).to be(true)
    end

    it "shows an ngo awaiting approval to the platform team" do
      create(:staff_role, user: user)

      expect(described_class.new(context_for(user), pending_ngo).show?).to be(true)
    end
  end

  describe "#create?" do
    it "asks only for a session" do
      aggregate_failures do
        expect(described_class.new(context_for(user), ngo).create?).to be(true)
        expect(described_class.new(Authorization::Context.anonymous, ngo).create?).to be(false)
      end
    end
  end

  describe "#update?" do
    it "allows only the roles that answer for the ngo" do
      permissions = %i[owner admin representative member].map do |role|
        described_class.new(context_with_role(role), ngo).update?
      end

      expect(permissions).to eq([true, true, false, false])
    end

    # Papel numa organização não vaza para outra: é o caso que um
    # `memberships.any?(&:owner?)` — sem perguntar em QUAL organização —
    # deixaria passar inteiro.
    it "refuses an owner of another ngo" do
      elsewhere = context_with_role(:owner, on: create(:ngo))

      expect(described_class.new(elsewhere, ngo).update?).to be(false)
    end

    it "allows the platform admin" do
      create(:staff_role, :admin, user: user)

      expect(described_class.new(context_for(user), ngo).update?).to be(true)
    end
  end

  describe "#destroy?" do
    it "asks for ownership, not administration" do
      owner = context_with_role(:owner)

      expect(described_class.new(owner, ngo).destroy?).to be(true)
    end

    it "refuses an ngo admin" do
      admin = context_with_role(:admin)

      expect(described_class.new(admin, ngo).destroy?).to be(false)
    end

    it "allows the platform admin" do
      create(:staff_role, :admin, user: user)

      expect(described_class.new(context_for(user), ngo).destroy?).to be(true)
    end

    it "refuses a support staff without a bond" do
      create(:staff_role, user: user)

      expect(described_class.new(context_for(user), ngo).destroy?).to be(false)
    end
  end

  def policy_for(actor: user, actor_profile: profile, role: nil, accepted: true)
    create_membership(profile: actor_profile, role:, accepted:) if role
    described_class.new(Authorization::Context.for(actor), ngo)
  end

  def create_membership(profile:, role:, accepted:)
    create(:membership, profile:, ngo:, role:,
                        accepted_at: accepted ? Time.current : nil)
  end

  def staff_policy(staff_level)
    actor = create(:user)
    create(:staff_role, user: actor, staff_level:)
    described_class.new(Authorization::Context.for(actor), ngo)
  end

  it "lets anyone list and view an approved ngo" do
    anonymous = Authorization::Context.anonymous

    expect(described_class.new(anonymous, ngo)).to have_attributes(index?: true, show?: true)
  end

  it "hides a pending ngo from every viewer" do
    pending = create(:ngo)
    anonymous = Authorization::Context.anonymous

    expect(described_class.new(anonymous, pending)).not_to be_show
  end

  it "requires a signed-in user to create" do
    anonymous = Authorization::Context.anonymous

    expect(described_class.new(anonymous, ngo)).not_to be_create
    expect(described_class.new(context, ngo)).to be_create
  end

  it "gives an accepted owner management access" do
    expect(policy_for(role: :owner)).to have_attributes(update?: true, destroy?: true)
  end

  it "gives an accepted admin update access but not destroy access" do
    actor = create(:user)
    actor_profile = create(:profile, user: actor)

    expect(policy_for(actor:, actor_profile:, role: :admin)).to have_attributes(update?: true, destroy?: false)
  end

  it "does not grant management to a member" do
    expect(policy_for(role: :member)).not_to be_update
  end

  it "does not grant management to a pending invitation" do
    expect(policy_for(role: :owner, accepted: false)).not_to be_update
  end

  it "does not grant a role in one ngo to another" do
    other = create(:ngo, ngo_status: :active)
    expect(described_class.new(context, other)).not_to be_update
  end

  it "lets platform admins manage and approve" do
    expect(staff_policy(:admin)).to have_attributes(update?: true, destroy?: true, approve?: true)
  end

  it "lets curators approve but not manage" do
    expect(staff_policy(:curator)).to have_attributes(update?: false, approve?: true)
  end

  it "does not let support approve" do
    expect(staff_policy(:support)).not_to be_approve
  end

  it "resolves visible ngos through the policy scope" do
    visible = create(:ngo, ngo_status: :active)
    create(:ngo)

    expect(described_class::Scope.new(context, Ngo.all).resolve).to include(visible)
  end
end
