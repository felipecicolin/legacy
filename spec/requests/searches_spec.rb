# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search" do
  let(:country) { create(:country) }
  let(:ngo) { create(:ngo, :active, country: country, name: "Base do Vale Verde") }

  def open_public(base)
    base.promote_visibility!(level: :public, author: create(:user), justification: "vitrine")
  end

  # A propriedade que a issue chama de "não pode ser oráculo", escrita como ela
  # é de fato verificável: a EXISTÊNCIA de um registro fora do alcance não pode
  # mudar a resposta. Comparar dois termos diferentes não serviria — a tela
  # devolve o termo no campo, e aí os corpos diferem pelo que a pessoa digitou,
  # não pelo que o banco tem.
  describe "a record the reader cannot reach" do
    it "answers exactly as if the record were not there" do
      get search_path(query: "escondida")
      without_it = [response.status, response.body]

      create(:ngo, :active, country: create(:country, high_risk: true), name: "Base Escondida")
      get search_path(query: "escondida")

      expect([response.status, response.body]).to eq(without_it)
    end
  end

  describe "the state in the URL" do
    before { open_public(ngo) }

    it "reproduces the search from the query string alone" do
      get search_path(query: "vale")

      expect(response.body).to include(ngo.name)
    end

    it "keeps a filter that was applied" do
      get search_path(query: "vale", ngo_kind: "school")

      expect(response.body).not_to include(ngo.name)
    end

    it "opens without a term at all" do
      get search_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(ngo.name)
      end
    end
  end

  describe "the presentation the reader chose" do
    before { open_public(ngo) }

    it "starts as a table" do
      get search_path(query: "vale")

      expect(response.body).to include("<table")
    end

    it "switches to the grid when asked" do
      get search_path(query: "vale", view: "grid")

      expect(response.body).not_to include("<table")
    end

    # A escolha é de leitura e persiste: quem escolheu grade não escolhe de
    # novo a cada busca.
    it "remembers the choice on the next search" do
      get search_path(query: "vale", view: "grid")
      get search_path(query: "vale")

      expect(response.body).not_to include("<table")
    end

    it "ignores a presentation that does not exist" do
      get search_path(query: "vale", view: "carrossel")

      expect(response.body).to include("<table")
    end
  end

  describe "the empty state" do
    # Os três casos do estado vazio são coisas diferentes. O terceiro — "sem
    # permissão" — nunca é dito: ele se apresenta como o segundo.
    it "says the filter found nothing when there was a term" do
      get search_path(query: "nada-casa-com-isto")

      expect(response.body).to include(I18n.t("searches.empty.no_match_title"))
    end

    it "says there is nothing yet when there was no term" do
      get search_path

      expect(response.body).to include(I18n.t("searches.empty.nothing_yet_title"))
    end
  end
end
