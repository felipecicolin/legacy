# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search screen" do
  let(:country) { create(:country) }
  let(:ngo) { create(:ngo, :active, country: country, name: "Base do Vale Verde") }

  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  before do
    ngo.promote_visibility!(level: :public, author: create(:user), justification: "vitrine")
  end

  # Sem recarregar a página: o formulário aponta para o frame, e é o Turbo que
  # troca só a lista. Se isto quebrar, a busca volta a piscar a página inteira.
  it "replaces the results inside the frame while typing" do
    visit search_path
    fill_in "query", with: "vale"

    expect(page).to have_css("#search_results", text: ngo.name)
  end

  it "keeps the term in the field after the frame comes back" do
    visit search_path(query: "vale")

    expect(page).to have_field("query", with: "vale")
  end

  it "fits the viewport at phone, tablet and desktop widths" do
    create_list(:project, 3, ngo: ngo)

    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit search_path(query: "vale")

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
