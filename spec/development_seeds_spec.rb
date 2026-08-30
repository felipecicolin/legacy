# frozen_string_literal: true

require "rails_helper"

# O seed mínimo é o que faz a trilha de frontend abrir um preview com conteúdo
# e a de dados ter linha em que agregar. Ele cresce junto com os modelos, então
# o que este arquivo cobra não é o conteúdo de hoje: é que carregar continue
# sendo uma operação segura de repetir. Ver docs/field.md.
# Os arquivos são definição pura — carregá-los aqui não grava nada. Quem grava
# é `load_all!`, e ele roda dentro do exemplo, na transação da fixture.
Rails.root.glob("db/seeds/development/*.rb").sort.each { |file| load file }

RSpec.describe DevelopmentSeeds do
  def load_seeds = described_class.load_all!

  def bases_visible_at(clearance)
    MissionBase.visible_to(Visibility::Context.new(clearance: clearance)).count
  end

  # Idempotência não é conveniência: o seed roda de novo toda vez que alguém
  # recarrega a demo, e um `create!` solto transformaria a segunda carga em
  # violação de índice único.
  it "loads twice without duplicating anything" do
    load_seeds
    counts = -> { [MissionBase.count, Project.count, ProjectParticipation.count, Need.count] }
    first = counts.call

    load_seeds

    expect(counts.call).to eq(first)
  end

  # A necessidade da BASE, sem obra, é o caso que justifica base e obra serem
  # tabelas diferentes — e o seed precisa mostrá-lo já na primeira carga.
  it "seeds a need that hangs from a base with no project" do
    load_seeds

    expect(Need.where(project_id: nil)).to be_present
  end

  it "covers the five states of the design system" do
    load_seeds

    expect(Project.group(:status).count.keys).to match_array(Project.statuses.keys)
  end

  # A base confidencial existe para NÃO aparecer: é o teste visual da política
  # de sensibilidade, e sem uma base aberta ao lado não haveria contraste.
  #
  # A propriedade, e não a contagem: uma camada nova no seed muda os números e
  # não muda o que importa.
  describe "what each level of clearance reaches" do
    subject(:counts) { %i[public restricted confidential].map { |level| bases_visible_at(level) } }

    before { load_seeds }

    it "never shrinks as the clearance grows" do
      expect(counts).to eq(counts.sort)
    end

    it "answers a different set to each of the three" do
      expect(counts.uniq.size).to eq(3)
    end

    it "shows something to an anonymous reader" do
      expect(counts.first).to be_positive
    end
  end

  # Abrir uma base passa pela porta de verdade, que exige autor e
  # justificativa — e a segunda carga não pode registrar a promoção de novo.
  # O que se mede é a IDEMPOTÊNCIA, não quantas bases o seed abre hoje.
  describe "the disclosures it records" do
    let(:first_run) { load_seeds && SensitivityChange.count }

    it "opens at least one base" do
      expect(first_run).to be_positive
    end

    it "records each one once, however many times it runs" do
      first_run

      expect { load_seeds }.not_to(change { SensitivityChange.count })
    end
  end
end
