# frozen_string_literal: true

require "rails_helper"

# A tela inteira, no navegador, com o CSS de verdade. O que só ela responde é
# se a tabela do histórico cabe na tela do telefone — nenhum spec de request
# lê largura.
RSpec.describe "Mission base detail screen" do
  let(:country) { create(:country) }
  let(:mission_base) { create(:mission_base, :active, country: country) }

  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  before do
    mission_base.promote_visibility!(level: :public, author: create(:user), justification: "vitrine")
    create_list(:project, 3, mission_base: mission_base)
    create(:need, mission_base: mission_base, title: "Cimento e areia")
  end

  it "fits the viewport at phone, tablet and desktop widths" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit mission_base_path(mission_base.slug)

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  it "shows the history and the standing needs side by side on the page" do
    visit mission_base_path(mission_base.slug)

    aggregate_failures do
      expect(page).to have_css("h1", text: mission_base.name)
      expect(page).to have_text(I18n.t("mission_bases.show.history"))
      expect(page).to have_text("Cimento e areia")
    end
  end
end
