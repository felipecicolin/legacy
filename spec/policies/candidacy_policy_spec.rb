# frozen_string_literal: true

require "rails_helper"

RSpec.describe CandidacyPolicy do
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }
  let(:need) { create(:need) }

  def context_for(record) = Authorization::Context.for(record.reload)

  def policy_for(candidacy, as: user) = described_class.new(context_for(as), candidacy)

  describe "an individual candidacy" do
    it "allows the person it belongs to" do
      expect(policy_for(build(:candidacy, need: need, profile: profile)).create?).to be(true)
    end

    it "refuses someone applying in another person's name" do
      stranger = create(:user).tap { |record| create(:profile, user: record) }

      expect(policy_for(build(:candidacy, need: need, profile: profile), as: stranger).create?).to be(false)
    end

    it "refuses an anonymous visitor" do
      candidacy = build(:candidacy, need: need, profile: profile)

      expect(described_class.new(Authorization::Context.anonymous, candidacy).create?).to be(false)
    end
  end

  # Inscrever a turma inteira é decisão de quem responde por ela. Um membro
  # comum se candidata por si, pelo caminho individual.
  describe "a group candidacy" do
    let(:group) { create(:volunteer_group, coordinator: profile) }
    let(:candidacy) { build(:candidacy, need: need, profile: nil, volunteer_group: group) }

    it "allows the coordinator of the group" do
      expect(policy_for(candidacy).create?).to be(true)
    end

    it "refuses a member who does not coordinate it" do
      member = create(:user).tap { |record| create(:profile, user: record) }

      expect(policy_for(candidacy, as: member).create?).to be(false)
    end
  end

  describe "#show?" do
    it "shows a candidacy to the person it belongs to" do
      expect(policy_for(create(:candidacy, need: need, profile: profile)).show?).to be(true)
    end

    it "shows it to the platform team" do
      staff = create(:user).tap { |record| create(:staff_role, user: record) }

      expect(policy_for(create(:candidacy, need: need, profile: profile), as: staff).show?).to be(true)
    end

    it "hides it from a stranger" do
      stranger = create(:user).tap { |record| create(:profile, user: record) }

      expect(policy_for(create(:candidacy, need: need, profile: profile), as: stranger).show?).to be(false)
    end
  end
end
