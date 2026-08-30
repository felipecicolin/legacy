# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project do
  describe "code" do
    it "numbers projects sequentially in the OB-%04d format" do
      codes = create_list(:project, 2).map(&:code)

      expect(codes).to all(match(/\AOB-\d{4}\z/))
    end

    it "never repeats a code" do
      codes = create_list(:project, 3).map(&:code)

      expect(codes.uniq.size).to eq(3)
    end

    # O que garante unicidade sob concorrência é o MECANISMO, e é ele que este
    # exemplo prende: o número vem de uma sequence do Postgres, que é atômica e
    # não bloqueia. Um `maximum(:code) + 1` em Ruby passaria em todos os outros
    # exemplos deste arquivo e ainda assim produziria códigos repetidos sob
    # duas criações simultâneas — a diferença entre os dois não é observável
    # sequencialmente, então o teste é sobre o default da coluna.
    it "takes the number from a database sequence, not from Ruby" do
      default = described_class.columns.find { |column| column.name == "code_number" }.default_function

      expect(default).to match(/\Anextval\(/)
    end

    # A imutabilidade não depende de `attr_readonly` nem de callback: `code` é
    # coluna GERADA, e o Postgres recusa escrita nela por qualquer caminho —
    # inclusive `update_all` e SQL cru, que é onde o `attr_readonly` de
    # `Ngo#slug` não alcança.
    #
    # Sem leitura de volta depois da recusa, de propósito: o Postgres aborta a
    # transação ao reprovar o statement, e a transação aqui é a do exemplo.
    # Qualquer consulta seguinte morreria com "current transaction is aborted",
    # e o exemplo passaria a falhar por outro motivo que não o dele.
    it "refuses to be written, even by raw SQL" do
      create(:project)

      expect { described_class.connection.execute("update projects set code = 'OB-9999'") }
        .to raise_error(ActiveRecord::StatementInvalid, /code/)
    end

    it "interpolates as its code" do
      expect(create(:project).to_s).to match(/\AOB-\d{4}\z/)
    end
  end

  describe "the five states of the design system" do
    it "declares exactly the five states, in the order the badge expects" do
      expect(described_class.statuses.keys).to eq(%w[surveying in_progress paused urgent completed])
    end

    # As duas listas são a mesma constante escrita duas vezes, em issues
    # diferentes (#26 e #8). Este exemplo é o que impede um estado novo de
    # entrar de um lado só — a obra ganharia um status que o badge recusa no
    # construtor, e a tela quebraria só quando essa obra aparecesse nela.
    it "declares the same states that the status badge knows how to draw" do
      expect(described_class.statuses.keys).to eq(StatusBadgeComponent::STATUSES.keys)
    end

    it "labels the state in pt-BR" do
      expect(build(:project, status: :in_progress).status_label).to eq("Em obra")
    end

    it "refuses a state outside the enum as a validation, not an exception" do
      project = build(:project).tap { |record| record.status = "demolida" }

      expect(project).not_to be_valid
    end
  end

  describe "transitions" do
    # A coordenação entra em toda obra da matriz porque a passagem para
    # execução a exige, e o que esta matriz mede é o GRAFO de transições — não
    # o invariante de equipe, que tem exemplos próprios logo abaixo.
    def transition(from, to)
      project = create(:project)
      create(:project_participation, :coordinator, project: project)
      project.update_column(:status, described_class.statuses.fetch(from))
      project.reload.update(status: to)
    end

    # A matriz inteira, e não uma amostra: é ela que pega um estado novo cujo
    # grafo de transições ninguém lembrou de atualizar.
    it "allows exactly the transitions the domain declares" do
      matrix = described_class.statuses.keys.index_with do |from|
        described_class.statuses.keys.reject { |to| to == from }.select { |to| transition(from, to) }
      end

      expect(matrix).to eq(described_class::TRANSITIONS)
    end

    # Reabrir obra é criar obra nova: senão o mesmo código responde por dois
    # ciclos com orçamentos diferentes, e a prestação de contas fica ambígua.
    # A obra entra em levantamento sem equipe; é a passagem para execução que
    # exige alguém que responda por ela.
    it "refuses to start the work without a coordinator" do
      project = create(:project)

      expect(project.update(status: :in_progress)).to be(false)
    end

    it "starts the work once a coordinator is in place" do
      project = create(:project)
      create(:project_participation, :coordinator, project: project)

      expect(project.update(status: :in_progress)).to be(true)
    end

    # Convite pendente não conta como coordenação.
    it "refuses a coordinator who was only invited" do
      project = create(:project)
      create(:project_participation, project: project, participation_role: :coordinator,
                                     participation_status: :invited)

      expect(project.update(status: :in_progress)).to be(false)
    end

    it "makes completed terminal" do
      expect(described_class::TRANSITIONS.fetch("completed")).to be_empty
    end

    it "accepts a save that does not touch the state" do
      project = create(:project, status: :surveying)

      expect(project.update(title: "Outro nome")).to be(true)
    end

    # A validação pega o formulário; isto pega `save(validate: false)`, que
    # grava sem validar.
    it "raises when the state is forced past the validations" do
      project = create(:project)
      project.status = :completed

      expect { project.save(validate: false) }.to raise_error(described_class::InvalidTransition, /surveying/)
    end
  end

  describe "sensitivity" do
    it "inherits the level of its base" do
      base = create(:ngo, country: create(:country, high_risk: true))

      expect(create(:project, ngo: base)).to be_confidential
    end

    it "keeps its own level when the base is more open" do
      expect(create(:project).sensitivity_level).to eq("restricted")
    end

    # O piso vale para sempre, e não só na criação: a base apertada depois não
    # pode deixar para trás uma obra mais aberta que ela.
    it "refuses to stay more open than a base that was tightened later" do
      project = create(:project)
      project.ngo.update_column(:sensitivity_level, Sensitive::LEVELS.fetch(:confidential))

      expect(project.reload).not_to be_valid
    end

    it "lets an invalid level be refused by the enum instead of blowing up the floor check" do
      project = build(:project).tap { |record| record.sensitivity_level = "secretissimo" }

      expect { project.valid? }.not_to raise_error
    end

    # `sensitivity_level` é NOT NULL com default, então `nil` só chega por um
    # PATCH que limpe o campo. O `&.` de `own_rank` existe para esse caminho:
    # sem ele, a checagem de piso levantaria `NoMethodError` antes de a
    # validação do enum ter chance de falar.
    it "lets a cleared level be refused by the enum instead of blowing up the floor check" do
      project = build(:project).tap { |record| record.sensitivity_level = nil }

      expect { project.valid? }.not_to raise_error
    end

    it "survives having no base yet, so the presence validation is the one that speaks" do
      expect(build(:project, ngo: nil)).not_to be_valid
    end
  end

  describe "#recalculate_physical_progress" do
    let(:project) { create(:project) }

    it "answers zero while no report was approved" do
      create(:progress_report, project: project, physical_progress: 40)

      expect { project.recalculate_physical_progress }.not_to(change { project.reload.physical_progress })
    end

    # O spec que a issue pede: corromper a coluna à mão e verificar que o
    # recálculo a conserta. É o que prova que a coluna é cache, e não verdade.
    it "repairs a column that was corrupted by hand" do
      create(:progress_report, :approved, project: project, physical_progress: 62)
      project.update_column(:physical_progress, 99)

      expect { project.recalculate_physical_progress }.to change { project.reload.physical_progress }.from(99).to(62)
    end
  end

  it "refuses a negative funding target" do
    expect(build(:project, funding_target_cents: -1)).not_to be_valid
  end

  it "refuses a progress outside the range" do
    expect(build(:project, physical_progress: 101)).not_to be_valid
  end

  it "refuses a currency that is not a three letter code" do
    expect(build(:project, currency: "REAIS")).not_to be_valid
  end

  describe "#cover_photo" do
    it "picks the photo with the lowest category, then position" do
      project = create(:project)
      create(:project_photo, project: project, photo_category: :after, position: 0)
      earliest = create(:project_photo, project: project, photo_category: :before, position: 0)

      expect(project.reload.cover_photo).to eq(earliest)
    end

    it "returns nil without any photo" do
      expect(create(:project).cover_photo).to be_nil
    end
  end

  describe "#primary_campaign" do
    it "picks the most recently created active or reached campaign" do
      project = create(:project)
      create(:campaign, :closed, project: project, mission_base: project.mission_base)
      recent = create(:campaign, project: project, mission_base: project.mission_base)

      expect(project.reload.primary_campaign).to eq(recent)
    end

    it "returns nil without any campaign" do
      expect(create(:project).primary_campaign).to be_nil
    end
  end

  # A validação pega o formulário; o CHECK pega seed, console e SQL cru.
  it "refuses a progress outside the range in the database too" do
    project = create(:project)

    corrupt = "update projects set physical_progress = 140 where id = #{project.id}"

    expect { described_class.connection.execute(corrupt) }
      .to raise_error(ActiveRecord::StatementInvalid, /physical_progress/)
  end

  # Obra em levantamento ainda não tem estimativa, e um zero mentiria dizendo
  # que ela não alcança ninguém. Ver docs/investor-dashboard.md.
  describe "the annual reach estimate" do
    it "refuses a negative estimate" do
      expect(build(:project, estimated_annual_reach: -1)).not_to be_valid
    end

    it "accepts an estimate that was never made" do
      expect(build(:project, estimated_annual_reach: nil)).to be_valid
    end
  end
end
