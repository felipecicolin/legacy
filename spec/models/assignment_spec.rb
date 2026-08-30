# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assignment do
  let(:mission_base) { create(:mission_base) }
  let(:project) { create(:project, mission_base: mission_base) }
  let(:need) { create(:need, mission_base: mission_base, project: project, quantity: 2) }

  describe "taking the slot" do
    it "counts against the need it fulfils" do
      create(:assignment, need: need, candidacy: create(:candidacy, need: need), quantity: 2)

      expect(need.reload.need_status).to eq("fulfilled")
    end

    it "refuses to take more than what is left" do
      create(:assignment, need: need, candidacy: create(:candidacy, need: need), quantity: 2)

      expect { create(:assignment, need: need, candidacy: create(:candidacy, need: need)) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # Um caminho só: dois caminhos separados produziriam voluntário alocado que
  # não aparece na equipe, e ninguém descobriria até a obra começar.
  describe "joining the project team" do
    let(:candidacy) { create(:candidacy, need: need) }

    it "puts the person on the team of the project" do
      assignment = create(:assignment, need: need, candidacy: candidacy)

      expect(project.project_participations.pluck(:profile_id)).to eq([assignment.candidacy.profile_id])
    end

    it "puts them there as an active volunteer" do
      create(:assignment, need: need, candidacy: candidacy)

      expect(project.project_participations.first).to be_active
    end

    it "takes them off the team when the assignment is cancelled" do
      assignment = create(:assignment, need: need, candidacy: candidacy)

      expect { assignment.update!(assignment_status: :cancelled) }
        .to change { project.project_participations.count }.from(1).to(0)
    end

    it "takes them off the team when the assignment is destroyed" do
      assignment = create(:assignment, need: need, candidacy: candidacy)

      expect { assignment.destroy! }.to change { project.project_participations.count }.from(1).to(0)
    end

    # Necessidade de base não tem obra: é o caso normal da necessidade que
    # existe sem obra ativa, e alocar nela não põe ninguém em equipe nenhuma.
    context "with a need that hangs from a base" do
      let(:base_need) { create(:need, mission_base: mission_base, project: nil) }
      let(:assignment) { create(:assignment, need: base_need, candidacy: create(:candidacy, need: base_need)) }

      before { assignment }

      it "creates no participation" do
        expect(ProjectParticipation.count).to eq(0)
      end

      # E cancelar não procura equipe nenhuma para desfazer. O `before` importa:
      # com a alocação criada dentro do `expect`, ela abateria e estornaria na
      # mesma medição, e o exemplo passaria a não observar mudança nenhuma.
      it "cancels without looking for a team to leave" do
        expect { assignment.update!(assignment_status: :cancelled) }
          .to change { base_need.reload.need_status }.from("fulfilled").to("open")
      end
    end

    # Quem participa da obra é pessoa: candidatura de grupo abate a
    # necessidade e não produz participação.
    it "creates no participation for a group candidacy" do
      group_candidacy = create(:candidacy, :from_a_group, need: need)
      create(:assignment, need: need, candidacy: group_candidacy)

      expect(project.project_participations.count).to eq(0)
    end
  end

  describe "giving the slot back" do
    it "reopens the need when cancelled" do
      assignment = create(:assignment, need: need, candidacy: create(:candidacy, need: need), quantity: 2)

      expect { assignment.update!(assignment_status: :cancelled) }
        .to change { need.reload.need_status }.from("fulfilled").to("open")
    end

    it "keeps counting while the assignment is merely progressing" do
      assignment = create(:assignment, need: need, candidacy: create(:candidacy, need: need), quantity: 2)

      expect { assignment.update!(assignment_status: :in_progress) }
        .not_to(change { need.reload.fulfilled_quantity })
    end
  end

  describe "what it refuses" do
    it "keeps one assignment per candidacy" do
      candidacy = create(:candidacy, need: need)
      create(:assignment, need: need, candidacy: candidacy)

      expect(build(:assignment, need: need, candidacy: candidacy)).not_to be_valid
    end

    it "refuses a candidacy that was made to another need" do
      elsewhere = create(:candidacy, need: create(:need))

      expect(build(:assignment, need: need, candidacy: elsewhere)).not_to be_valid
    end

    it "refuses an end before the start" do
      assignment = build(:assignment, need: need, candidacy: create(:candidacy, need: need),
                                      starts_on: Date.current, ends_on: Date.current.yesterday)

      expect(assignment).not_to be_valid
    end

    it "refuses a quantity of zero" do
      expect(build(:assignment, need: need, candidacy: create(:candidacy, need: need), quantity: 0)).not_to be_valid
    end
  end

  it "translates the status to pt-BR" do
    assignment = build(:assignment, need: need, candidacy: create(:candidacy, need: need),
                                    assignment_status: :in_progress)

    expect(assignment.assignment_status_label).to eq("Em andamento")
  end
end
