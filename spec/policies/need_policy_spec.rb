# frozen_string_literal: true

require "rails_helper"

RSpec.describe NeedPolicy do
  let(:user) { create(:user) }
  let(:need) { create(:need) }

  def policy_for(record, context) = described_class.new(context, record)

  def signed_in_context
    create(:profile, user: user)
    Authorization::Context.for(user.reload)
  end

  it "shows a need the reader reaches" do
    expect(policy_for(need, signed_in_context).show?).to be(true)
  end

  # A recusa por não ver sai pela mesma porta da recusa por não existir.
  it "hides a need the reader does not reach" do
    hidden = create(:need, ngo: create(:ngo, country: create(:country, high_risk: true)))

    expect(policy_for(hidden, signed_in_context).show?).to be(false)
  end

  it "lets a signed in reader apply to a need they reach" do
    expect(policy_for(need, signed_in_context).create?).to be(true)
  end

  it "refuses an anonymous visitor" do
    expect(policy_for(need, Authorization::Context.anonymous).create?).to be(false)
  end

  it "opens the index to anyone" do
    expect(policy_for(need, Authorization::Context.anonymous).index?).to be(true)
  end
end
