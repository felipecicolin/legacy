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

  # Idempotência não é conveniência: o seed roda de novo toda vez que alguém
  # recarrega a demo, e um `create!` solto transformaria a segunda carga em
  # violação de índice único.
  it "loads twice without duplicating anything" do
    load_seeds
    counts = -> { [MissionBase.count, Project.count, ProjectParticipation.count] }
    first = counts.call

    load_seeds

    expect(counts.call).to eq(first)
  end

  it "covers the five states of the design system" do
    load_seeds

    expect(Project.group(:status).count.keys).to match_array(Project.statuses.keys)
  end

  # A base confidencial existe para NÃO aparecer: é o teste visual da política
  # de sensibilidade, e sem uma base aberta ao lado não haveria contraste.
  it "answers a different set of bases to each level of clearance" do
    load_seeds

    counts = %i[public restricted confidential].map do |clearance|
      MissionBase.visible_to(Visibility::Context.new(clearance: clearance)).count
    end

    expect(counts).to eq([1, 3, 4])
  end

  # Abrir uma base passa pela porta de verdade, que exige autor e
  # justificativa — e a segunda carga não pode registrar a promoção de novo.
  it "records the disclosure once, however many times it runs" do
    load_seeds
    load_seeds

    expect(SensitivityChange.count).to eq(1)
  end
end
