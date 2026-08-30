# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProgressReportPolicy do
  let(:project) { create(:project) }
  let(:report) { build(:progress_report, project: project) }
  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }

  def context_for(user_record) = Authorization::Context.for(user_record.reload)

  def policy_with(role, status: :active)
    create(:project_participation, project: project, profile: profile, role: role, status: status)
    described_class.new(context_for(user), report)
  end

  describe "#create?" do
    # Relatório é prestação de contas: quem assina responde por ele. Voluntário
    # e observador não assinam.
    it "allows only the roles that answer for the work" do
      answers = %i[coordinator technical_lead volunteer observer].map do |role|
        project.project_participations.delete_all
        policy_with(role).create?
      end

      expect(answers).to eq([true, true, false, false])
    end

    it "refuses someone who was only invited" do
      expect(policy_with(:coordinator, status: :invited).create?).to be(false)
    end

    it "refuses someone with no bond to the project" do
      profile

      expect(described_class.new(context_for(user), report).create?).to be(false)
    end

    it "refuses an anonymous reader" do
      expect(described_class.new(Authorization::Context.anonymous, report).create?).to be(false)
    end
  end

  describe "#show?" do
    it "allows anyone actively taking part in the work" do
      expect(policy_with(:volunteer).show?).to be(true)
    end

    it "allows the platform team" do
      create(:staff_role, user: user)

      expect(described_class.new(context_for(user), report).show?).to be(true)
    end

    it "refuses a stranger" do
      profile

      expect(described_class.new(context_for(user), report).show?).to be(false)
    end
  end

  # Correção é relatório novo: não há caminho de edição liberado para ninguém,
  # e o default de recusa da base é o que sustenta isso.
  it "leaves editing refused for everyone" do
    expect(policy_with(:coordinator).update?).to be(false)
  end
end
