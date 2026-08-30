# frozen_string_literal: true

require "rails_helper"

RSpec.describe Need do
  let(:ngo) { create(:ngo) }

  describe "where a need hangs from" do
    # É o caso que justifica base e obra serem tabelas diferentes: a base tem
    # necessidade mesmo sem obra ativa.
    it "accepts a need on a base with no project at all" do
      expect(build(:need, ngo: ngo, project: nil)).to be_valid
    end

    it "accepts a need on a project of its own base" do
      expect(build(:need, :for_project, ngo: ngo)).to be_valid
    end

    # Sem isto o registro aponta para a base A pela coluna e para a base B pela
    # obra, e os dois rollups discordam — sem erro em lugar nenhum.
    it "refuses a project that belongs to another base" do
      elsewhere = create(:project)

      expect(build(:need, ngo: ngo, project: elsewhere)).not_to be_valid
    end
  end

  describe "the skill that only one kind carries" do
    it "refuses a skill need with no skill" do
      expect(build(:need, ngo: ngo, need_kind: :skill, skill: nil)).not_to be_valid
    end

    # Nos dois sentidos: habilidade num pedido de material é dado decorativo
    # que a busca acaba filtrando por engano.
    it "refuses a material need that carries a skill" do
      expect(build(:need, ngo: ngo, need_kind: :material, skill: create(:skill))).not_to be_valid
    end

    it "accepts a skill need with a skill" do
      expect(build(:need, :skilled, ngo: ngo)).to be_valid
    end
  end

  describe "the quantity and the status derived from it" do
    it "walks from open to partially fulfilled to fulfilled on its own" do
      need = create(:need, ngo: ngo, quantity: 10)
      statuses = [0, 4, 10].map { |done| need.tap { |record| record.update!(fulfilled_quantity: done) }.need_status }

      expect(statuses).to eq(%w[open partially_fulfilled fulfilled])
    end

    # `cancelled` é decisão humana, e a derivação não pode desfazê-la.
    it "leaves a cancelled need cancelled" do
      need = create(:need, ngo: ngo, quantity: 10, need_status: :cancelled)

      expect(need.tap { |record| record.update!(fulfilled_quantity: 3) }.need_status).to eq("cancelled")
    end

    it "refuses more fulfilled than asked for" do
      expect(build(:need, ngo: ngo, quantity: 2, fulfilled_quantity: 3)).not_to be_valid
    end

    it "refuses a quantity of zero" do
      expect(build(:need, ngo: ngo, quantity: 0)).not_to be_valid
    end

    # A validação pega o formulário; o CHECK é a trava em que o abatimento
    # concorrente de #33 vai se apoiar.
    it "refuses more fulfilled than asked for in the database too" do
      need = create(:need, ngo: ngo, quantity: 2)
      corrupt = "update needs set fulfilled_quantity = 5 where id = #{need.id}"

      expect { described_class.connection.execute(corrupt) }
        .to raise_error(ActiveRecord::StatementInvalid, /fulfilled_within_quantity/)
    end
  end

  describe "sensitivity" do
    let(:risky) { create(:ngo, country: create(:country, high_risk: true)) }

    it "inherits from the base when there is no project" do
      expect(create(:need, ngo: risky)).to be_confidential
    end

    it "inherits from the project when there is one" do
      project = create(:project, ngo: risky)

      expect(create(:need, ngo: risky, project: project)).to be_confidential
    end

    it "keeps the closed default when the source is more open" do
      expect(create(:need, ngo: ngo).sensitivity_level).to eq("restricted")
    end

    it "survives having no base yet, so the presence validation is the one that speaks" do
      expect(build(:need, ngo: nil)).not_to be_valid
    end
  end

  describe ".matching" do
    let(:profile) { create(:profile) }
    let(:skill) { create(:skill) }

    before { create(:profile_skill, profile: profile, skill: skill) }

    it "answers the open needs that ask for a skill the person has" do
      wanted = create(:need, ngo: ngo, need_kind: :skill, skill: skill)
      create(:need, ngo: ngo, need_kind: :skill, skill: create(:skill))

      expect(described_class.matching(profile)).to contain_exactly(wanted)
    end

    it "leaves out a need that was already fulfilled" do
      create(:need, ngo: ngo, need_kind: :skill, skill: skill, quantity: 1, fulfilled_quantity: 1)

      expect(described_class.matching(profile)).to be_empty
    end

    it "leaves out a need that does not ask for a skill" do
      create(:need, ngo: ngo, need_kind: :material)

      expect(described_class.matching(profile)).to be_empty
    end
  end

  # Necessidade crítica em obra parada tem de subir, e a ordem de criação não
  # diz nada sobre urgência.
  describe ".by_priority" do
    it "puts the most urgent first, regardless of when it was created" do
      low = create(:need, ngo: ngo, urgency: :low)
      critical = create(:need, ngo: ngo, urgency: :critical)

      expect(described_class.by_priority).to eq([critical, low])
    end

    it "breaks a tie by the closest deadline" do
      later = create(:need, ngo: ngo, needed_by: 1.month.from_now.to_date)
      sooner = create(:need, ngo: ngo, needed_by: 1.week.from_now.to_date)

      expect(described_class.by_priority).to eq([sooner, later])
    end
  end

  describe "labels and presentation" do
    let(:need) { build(:need, ngo: ngo, need_kind: :team, urgency: :critical) }

    it "translates kind, urgency and status to pt-BR" do
      aggregate_failures do
        expect(need.need_kind_label).to eq("Equipe")
        expect(need.urgency_label).to eq("Crítica")
        expect(need.need_status_label).to eq("Aberta")
      end
    end

    it "interpolates as its title" do
      expect(build(:need, ngo: ngo, title: "Telhas").to_s).to eq("Telhas")
    end
  end

  it "refuses a negative estimate and a currency that is not a three letter code" do
    aggregate_failures do
      expect(build(:need, ngo: ngo, estimated_value_cents: -1)).not_to be_valid
      expect(build(:need, ngo: ngo, currency: "REAIS")).not_to be_valid
    end
  end
end
