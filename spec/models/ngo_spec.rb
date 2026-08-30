# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ngo do
  subject(:ngo) { build(:ngo) }

  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:profiles).through(:memberships) }
  it { is_expected.to validate_presence_of(:name) }

  it "starts out waiting for approval" do
    expect(described_class.new).to be_ngo_status_pending
  end

  it "derives the address from the name" do
    expect(create(:ngo, name: "Igreja da Paz").slug).to eq("igreja-da-paz")
  end

  it "keeps an address that was given" do
    expect(create(:ngo, slug: "paz").slug).to eq("paz")
  end

  # Campo de texto vazio chega do formulário como `""`, que é truthy — um `||=`
  # deixaria o slug em branco e a criação reprovaria por um campo opcional.
  it "derives the address when the given one arrives blank" do
    expect(create(:ngo, name: "Igreja da Paz", slug: "").slug).to eq("igreja-da-paz")
  end

  # Sem o sufixo, a segunda organização de mesmo nome reprovaria no índice
  # único — com um erro sobre um campo que ninguém preencheu.
  it "sets the two ngos of a same name apart" do
    create(:ngo, name: "Igreja Betel")
    second = create(:ngo, name: "Igreja Betel")

    expect(second.slug).to start_with("igreja-betel-")
  end

  # A URL pública é contrato com quem já a compartilhou. Renomear a
  # organização é normal; mudar o endereço dela não é.
  it "does not follow a later change to the name" do
    ngo = create(:ngo, name: "Igreja da Paz")
    ngo.update!(name: "Igreja da Paz e do Amor")

    expect(ngo.slug).to eq("igreja-da-paz")
  end

  it "refuses to change the address of an ngo that already exists" do
    ngo = create(:ngo)

    expect { ngo.update!(slug: "outro-endereco") }
      .to raise_error(ActiveRecord::ReadonlyAttributeError)
  end

  it "refuses a second ngo at the same address" do
    create(:ngo, slug: "paz")

    expect(build(:ngo, slug: "paz")).not_to be_valid
  end

  # Organização não aprovada não aparece em busca e não recebe doação. Este
  # escopo é o único lugar que decide isso.
  it "shows only the approved ngos" do
    approved = create(:ngo, ngo_status: :active)
    create(:ngo, ngo_status: :pending)
    create(:ngo, ngo_status: :suspended)

    expect(described_class.visible).to contain_exactly(approved)
  end

  it "refuses a kind that is not in the vocabulary" do
    expect(build(:ngo, ngo_kind: "ministry")).not_to be_valid
  end

  it "shows the kind through the pt-BR vocabulary" do
    expect(build(:ngo, ngo_kind: :association).ngo_kind_label).to eq("Associação")
  end

  it "shows the status through the pt-BR vocabulary" do
    expect(build(:ngo, ngo_status: :suspended).ngo_status_label).to eq("Suspensa")
  end

  it "shows the name when interpolated" do
    expect(build(:ngo, name: "Igreja da Paz").to_s).to eq("Igreja da Paz")
  end

  it "carries the description as rich text" do
    ngo = create(:ngo, description: "<div>Obra na fronteira</div>")

    expect(ngo.reload.description.to_plain_text).to eq("Obra na fronteira")
  end

  # Com `build` o anexo fica só na memória: `attached?` responderia true sem uma
  # única linha gravada, e nada provaria que as tabelas do Active Storage
  # aguentam a inserção.
  it "carries the logo as an Active Storage attachment" do
    ngo = create(:ngo)
    ngo.logo.attach(io: StringIO.new("bytes"), filename: "logo.png", content_type: "image/png")

    expect(ngo.reload.logo).to be_attached
  end

  # Tudo daqui para baixo veio do `mission_base_spec.rb` que a fusão apagou: é
  # o lado LUGAR da ONG, e sem estes exemplos os ramos que ele acrescentou ao
  # modelo ficariam sem cobertura.
  describe "sensitivity inherited from the country" do
    it "starts an ngo in a high risk country as confidential" do
      expect(create(:ngo, country: create(:country, high_risk: true))).to be_confidential
    end

    # A herança só APERTA. Um país `public` não abre a ONG, porque abrir é
    # promoção e promoção pede autor e justificativa.
    it "keeps the closed default when the country is more open" do
      country = create(:country).tap { |record| record.update!(default_sensitivity: :public) }

      expect(create(:ngo, country: country).sensitivity_level).to eq("restricted")
    end

    # País deixou de ser obrigatório na fusão — organização não tinha —, então
    # a herança precisa atravessar o caso sem país sem levantar nada.
    it "keeps the closed default when there is no country at all" do
      expect(create(:ngo, country: nil).sensitivity_level).to eq("restricted")
    end

    it "refuses a coordinate on a confidential ngo" do
      expect(build(:ngo, :located, country: create(:country, high_risk: true))).not_to be_valid
    end
  end

  describe "the coordinate" do
    # Faixa, e não só ausência em registro confidencial: uma latitude de 200
    # não localiza nada e não dá erro nenhum — o mapa não desenha o ponto, e
    # ninguém descobre por quê.
    it "refuses a coordinate outside the surface of the planet" do
      answers = [[91, 0], [0, 181], [-91, 0], [0, -181]].map do |latitude, longitude|
        build(:ngo, latitude: latitude, longitude: longitude).valid?
      end

      expect(answers).to all(be(false))
    end

    it "accepts a coordinate on the surface of the planet" do
      expect(build(:ngo, :located)).to be_valid
    end

    it "accepts an ngo whose coordinate was never recorded" do
      expect(build(:ngo, latitude: nil, longitude: nil)).to be_valid
    end
  end

  describe "the region" do
    # Sem ela a ONG aponta para um país pela coluna e para outro pela região, e
    # o rollup por país discorda do mapa.
    it "refuses a region from another country" do
      expect(build(:ngo, country: create(:country), region: create(:region))).not_to be_valid
    end

    it "accepts a region of its own country" do
      country = create(:country)

      expect(build(:ngo, country: country, region: create(:region, country: country))).to be_valid
    end

    it "accepts an ngo with no region" do
      expect(build(:ngo, region: nil)).to be_valid
    end
  end

  describe "place labels" do
    # O concern pede rótulo, e não associação: ele não conhece as tabelas de
    # país e de região.
    it "answers the country and region labels when there is a place" do
      country = create(:country)
      located = create(:ngo, country: country, region: create(:region, country: country, name: "Vale"))

      aggregate_failures do
        expect(located.country_label).to eq(country.name)
        expect(located.region_label).to eq("Vale")
      end
    end

    it "answers nothing for an ngo with no place recorded" do
      placeless = create(:ngo, country: nil, region: nil)

      aggregate_failures do
        expect(placeless.country_label).to be_nil
        expect(placeless.region_label).to be_nil
      end
    end
  end

  describe "projects" do
    it "accepts an ngo with no project at all" do
      expect(create(:ngo).projects).to be_empty
    end

    # Apagar ONG com obra é sempre erro humano: o histórico da obra é prestação
    # de contas, e some junto a resposta para "onde foi o dinheiro".
    it "refuses to be destroyed while a project points at it" do
      ngo = create(:ngo).tap { |record| create(:project, ngo: record) }

      aggregate_failures do
        expect(ngo.destroy).to be(false)
        expect(described_class.exists?(ngo.id)).to be(true)
      end
    end
  end

  describe "visibility to a reader" do
    before do
      create(:ngo, country: create(:country, high_risk: true))
      create(:ngo).promote_visibility!(level: :public, author: create(:user), justification: "vitrine")
    end

    it "answers a different set for anonymous, signed in and platform admin" do
      counts = %i[public restricted confidential].map do |clearance|
        described_class.visible_to(Visibility::Context.new(clearance: clearance)).count
      end

      expect(counts).to eq([1, 1, 2])
    end
  end

  it "refuses a negative headcount" do
    expect(build(:ngo, people_served: -1)).not_to be_valid
  end

  it "accepts an unknown headcount" do
    expect(build(:ngo, people_served: nil)).to be_valid
  end
end
