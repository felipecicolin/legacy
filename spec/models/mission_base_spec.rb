# frozen_string_literal: true

require "rails_helper"

RSpec.describe MissionBase do
  describe "slug" do
    it "derives the slug from the name" do
      expect(create(:mission_base, name: "Base do Vale Verde").slug).to eq("base-do-vale-verde")
    end

    it "keeps a slug given explicitly" do
      expect(create(:mission_base, name: "Base do Vale", slug: "vale").slug).to eq("vale")
    end

    # Campo de slug deixado em branco chega do formulário como `""`, que é
    # truthy — um `||=` não correria e a criação reprovaria por um campo
    # apresentado como opcional.
    it "treats a blank slug as absent" do
      expect(create(:mission_base, name: "Base do Vale", slug: "").slug).to eq("base-do-vale")
    end

    it "disambiguates a repeated name instead of failing on the unique index" do
      create(:mission_base, name: "Base do Vale")

      expect(create(:mission_base, name: "Base do Vale").slug).to match(/\Abase-do-vale-\h{6}\z/)
    end

    # URL pública que quebra é dívida permanente: quem compartilhou o link não
    # tem como saber que mudou.
    it "refuses to rewrite the slug of a base that already exists" do
      base = create(:mission_base)

      expect { base.update!(slug: "outro") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe "sensitivity inherited from the country" do
    it "starts a base in a high risk country as confidential" do
      base = create(:mission_base, country: create(:country, high_risk: true))

      expect(base).to be_confidential
    end

    # A herança só APERTA. Um país `public` não abre a base, porque abrir é
    # promoção e promoção pede autor e justificativa.
    it "keeps the closed default when the country is more open" do
      country = create(:country).tap { |record| record.update!(default_sensitivity: :public) }

      expect(create(:mission_base, country: country).sensitivity_level).to eq("restricted")
    end

    it "refuses a coordinate on a confidential base" do
      base = build(:mission_base, :located, country: create(:country, high_risk: true))

      expect(base).not_to be_valid
    end
  end

  describe "projects" do
    it "accepts a base with no project at all" do
      expect(create(:mission_base).projects).to be_empty
    end

    it "carries many projects" do
      base = create(:mission_base)
      create_list(:project, 3, mission_base: base)

      expect(base.projects.count).to eq(3)
    end

    # Apagar base com obra é sempre erro humano: o histórico da obra é
    # prestação de contas, e some junto a resposta para "onde foi o dinheiro".
    it "refuses to be destroyed while a project points at it" do
      base = create(:mission_base).tap { |record| create(:project, mission_base: record) }

      aggregate_failures do
        expect(base.destroy).to be(false)
        expect(described_class.exists?(base.id)).to be(true)
      end
    end
  end

  describe "visibility to a reader" do
    before do
      create(:mission_base, country: create(:country, high_risk: true))
      create(:mission_base).promote_visibility!(level: :public, author: create(:user), justification: "vitrine")
    end

    it "answers a different set for anonymous, signed in and platform admin" do
      counts = %i[public restricted confidential].map do |clearance|
        described_class.visible_to(Visibility::Context.new(clearance: clearance)).count
      end

      expect(counts).to eq([1, 1, 2])
    end
  end

  describe "labels" do
    let(:located) { create(:mission_base, country: country, region: create(:region, country: country, name: "Vale")) }
    # O concern pede rótulo, e não associação: ele não conhece as tabelas de
    # país e de região.
    let(:country) { create(:country) }

    it "translates kind and status to pt-BR" do
      base = build(:mission_base, base_kind: :school)

      aggregate_failures do
        expect(base.base_kind_label).to eq("Escola")
        expect(base.base_status_label).to eq("Pendente")
      end
    end

    it "answers the country label always and the region label only when there is one" do
      aggregate_failures do
        expect(located.country_label).to eq(country.name)
        expect(located.region_label).to eq("Vale")
        expect(create(:mission_base).region_label).to be_nil
      end
    end

    it "interpolates as its name" do
      expect(build(:mission_base, name: "Base do Vale").to_s).to eq("Base do Vale")
    end
  end

  describe "status" do
    it "hides a base that was not approved from the visible scope" do
      create(:mission_base)
      active = create(:mission_base, :active)

      expect(described_class.visible).to contain_exactly(active)
    end
  end

  it "refuses a negative headcount" do
    expect(build(:mission_base, people_served: -1)).not_to be_valid
  end

  it "accepts an unknown headcount" do
    expect(build(:mission_base, people_served: nil)).to be_valid
  end
end
