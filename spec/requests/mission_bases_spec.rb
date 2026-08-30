# frozen_string_literal: true

require "rails_helper"

# A tela que prova que Base e Obra são coisas diferentes. Se ela puder ser
# reduzida a "a obra da base", o modelo estava errado. Ver docs/field.md.
RSpec.describe "Mission base detail" do
  let(:country) { create(:country) }
  let(:mission_base) { create(:mission_base, :active, country: country) }

  def open_public(base)
    base.promote_visibility!(level: :public, author: create(:user), justification: "vitrine")
  end

  describe "a base with no project at all" do
    before do
      open_public(mission_base)
      create(:need, mission_base: mission_base, title: "Cimento e areia")
      get mission_base_path(mission_base.slug)
    end

    # A regra que a issue põe em primeiro lugar: a base sem obra renderiza
    # COMPLETA e útil. O estado vazio é da seção de obras, nunca da página.
    it "renders the page, not an empty state" do
      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(mission_base.name)
      end
    end

    it "still shows the needs that hang from the base" do
      expect(response.body).to include("Cimento e areia")
    end

    it "shows the empty state inside the project section" do
      expect(response.body).to include(I18n.t("mission_bases.projects.empty_title"))
    end
  end

  describe "the project history" do
    before { open_public(mission_base) }

    it "lists every project, including the ones already finished" do
      finished = create(:project, mission_base: mission_base)
      finished.update_column(:status, Project.statuses.fetch("completed"))

      get mission_base_path(mission_base.slug)

      expect(response.body).to include(finished.code)
    end

    it "carries five projects without complaining" do
      create_list(:project, 5, mission_base: mission_base)

      get mission_base_path(mission_base.slug)

      expect(response.body.scan(/OB-\d{4}/).uniq.size).to eq(5)
    end

    # A seção de necessidades é a DA BASE. Misturar as das obras apagaria a
    # distinção que esta tela existe para provar.
    it "leaves the needs of a project out of the base section" do
      project = create(:project, mission_base: mission_base)
      create(:need, mission_base: mission_base, project: project, title: "Andaime da obra")

      get mission_base_path(mission_base.slug)

      expect(response.body).not_to include("Andaime da obra")
    end
  end

  describe "a confidential base" do
    let(:hidden) { create(:mission_base, :active, country: create(:country, high_risk: true)) }

    # 404 e não 403: um 403 confirmaria que a base existe, e a existência já é
    # a informação que a política protege. Ver docs/authorization.md.
    it "answers exactly like a base that does not exist" do
      get mission_base_path(hidden.slug)
      hidden_response = [response.status, response.body]

      get mission_base_path("nao-existe")

      expect([response.status, response.body]).to eq(hidden_response)
    end

    it "keeps the region out of the HTML for a reader who does not reach it" do
      region = create(:region, country: hidden.country, name: "Vale do Norte")
      hidden.update!(region: region)

      get mission_base_path(hidden.slug)

      expect(response.body).not_to include("Vale do Norte")
    end
  end

  # `restricted` é o default, e o leitor anônimo para em `public`.
  it "hides a base that was never opened to the public" do
    get mission_base_path(mission_base.slug)

    expect(response).to have_http_status(:not_found)
  end
end
