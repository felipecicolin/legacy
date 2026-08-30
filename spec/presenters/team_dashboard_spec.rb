# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamDashboard do
  subject(:dashboard) { described_class.new(profile, Authorization::Context.for(user)) }

  let(:user) { create(:user) }
  let(:profile) { create(:profile, user: user) }
  let(:ngo) { create(:ngo, :active) }
  let(:project) { create(:project, ngo: ngo) }

  def join(target = project, role: :volunteer)
    create(:project_participation, :active, project: target, profile: profile, participation_role: role)
  end

  def approved_budget(cents)
    budget = create(:budget, project: project)
    create(:budget_line, budget: budget, estimated_cents: cents)
    budget.reload.approve
  end

  # Convite não é presença: `effective` é `active`, e um vínculo pendente não
  # põe obra nenhuma no painel.
  it "does not put someone on a team for an invitation they never accepted" do
    create(:project_participation, project: project, profile: profile)

    expect(dashboard).not_to be_on_a_team
  end

  it "lists the project of an active participation with the role that was played" do
    join(role: :coordinator)

    expect(dashboard.boards.map(&:role)).to eq([I18n.t("participation_roles.coordinator")])
  end

  # O nível da obra vale inclusive para quem está nela: o vínculo não é chave
  # que abre o que a sensibilidade fechou.
  it "leaves out a project the reader cannot reach, bond or no bond" do
    join(create(:project, ngo: create(:ngo, :active, country: create(:country, high_risk: true))))

    expect([dashboard.on_a_team?, dashboard.boards]).to eq([true, []])
  end

  describe "the money on the board" do
    before { join }

    it "reads the approved budget and leaves a rejected expense out of the spend" do
      approved_budget(400_000)
      create(:expense, project: project, amount_cents: 90_000, status: :approved)
      create(:expense, project: project, amount_cents: 70_000, status: :rejected)

      expect(dashboard.boards.first).to have_attributes(budgeted_cents: 400_000, spent_cents: 90_000)
    end

    # Sem orçamento aprovado o rascunho é o que o time está montando, e mostrar
    # zero esconderia o trabalho em curso.
    it "falls back to the draft while no budget has been approved" do
      budget = create(:budget, project: project)
      create(:budget_line, budget: budget, estimated_cents: 120_000)

      expect(dashboard.boards.first.budgeted_cents).to eq(120_000)
    end

    it "answers zero for a project with no budget at all" do
      expect(dashboard.boards.first.budgeted_cents).to eq(0)
    end

    it "sums the goal and the raised amount of every campaign of the project" do
      create(:campaign, ngo: ngo, project: project, goal_cents: 300_000)
        .update_column(:raised_cents, 186_000)

      expect(dashboard.boards.first).to have_attributes(goal_cents: 300_000, raised_cents: 186_000)
    end
  end

  it "hands the view the visibility of the context that asked" do
    expect(dashboard.visibility.clearance).to eq(:restricted)
  end
end
