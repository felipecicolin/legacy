# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Query do
  let(:country) { create(:country) }
  let(:mission_base) { create(:mission_base, :active, country: country, name: "Base do Vale Verde") }

  def search(term, context: staff_context, **filters)
    described_class.new(term: term, filters: Search::Filters.from(filters), context: context)
  end

  def staff_context
    user = create(:user)
    create(:staff_role, :admin, user: user)
    Authorization::Context.for(user.reload)
  end

  describe "the three groups in one box" do
    # É esta tela que prova por que Base, Obra e País são entidades separadas:
    # um termo casa os três, e cada um leva a um lugar diferente.
    it "answers project, base and country for a term that matches all three" do
      base = create(:mission_base, :active, country: country, name: "Vale Verde")
      create(:project, mission_base: base, title: "Reforma do Vale")
      allow(country).to receive(:name).and_return("Vale")

      expect(search("vale").groups.values.map(&:any?)).to eq([true, true, false])
    end

    it "counts every group together" do
      create(:project, mission_base: mission_base, title: "Reforma do Vale")

      expect(search("vale").total).to eq(2)
    end
  end

  describe "accents and case" do
    let!(:accented) { create(:mission_base, :active, country: country, name: "Clínica do Sertão") }

    # "sao paulo" tem de achar "São Paulo": quem digita rápido não acentua, e
    # sem isso conclui que o dado não existe.
    it "finds accented data from an unaccented term" do
      expect(search("clinica do sertao").groups.fetch(:mission_bases)).to include(accented)
    end

    it "finds it whatever the case" do
      expect(search("CLÍNICA").groups.fetch(:mission_bases)).to include(accented)
    end

    it "finds unaccented data from an accented term" do
      plain = create(:mission_base, :active, country: country, name: "Casa Norte")

      expect(search("Cása").groups.fetch(:mission_bases)).to include(plain)
    end
  end

  describe "what a reader cannot reach" do
    let(:hidden_country) { create(:country, high_risk: true) }
    let!(:hidden) { create(:mission_base, :active, country: hidden_country, name: "Base Escondida") }

    # Buscar não pode virar oráculo: a resposta para quem não alcança é
    # indistinguível da resposta para um termo que não casa nada.
    it "answers nothing at all, not a redacted row" do
      expect(search("escondida", context: Authorization::Context.anonymous).any_result?).to be(false)
    end

    it "answers it to a reader who reaches it" do
      expect(search("escondida").groups.fetch(:mission_bases)).to include(hidden)
    end

    it "offers no country filter for a country the reader cannot reach" do
      countries = search(nil, context: Authorization::Context.anonymous).filterable_countries

      expect(countries).not_to include(hidden_country)
    end
  end

  describe "with no term at all" do
    before { create(:project, mission_base: mission_base) }

    # A busca vazia é a listagem: "ver tudo" não é uma tela à parte. Uma obra,
    # uma base e o país que a contém — o país entra porque tem base alcançável.
    it "answers everything the reader reaches" do
      expect(search(nil).groups.transform_values(&:count)).to eq(projects: 1, mission_bases: 1, countries: 1)
    end

    it "knows it is not searching" do
      expect(search(nil)).not_to be_searching
    end
  end

  describe "#to_query" do
    it "carries the term and the filters that were set" do
      expect(search("vale", status: "paused").to_query).to eq(query: "vale", status: "paused")
    end

    it "leaves out what was never set" do
      expect(search(nil).to_query).to eq({})
    end
  end
end
