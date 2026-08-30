# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Investor view screen" do
  let(:password) { "s3nha-de-teste-longa" }
  let(:user) { create(:user, password: password) }
  let(:profile) { create(:profile, user: user) }
  let(:ngo) { create(:ngo, :active) }

  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  def sign_in
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_on I18n.t("sessions.new.submit")
    # `click_on` volta antes de a navegação terminar. Sem esperar o redirect, o
    # `visit` seguinte corre sem sessão — e o exemplo de viewport passa medindo
    # a tela de login, que é pior do que falhar. O destino é a dash: a raiz
    # despacha em vez de renderizar.
    expect(page).to have_current_path(investor_path, wait: 5)
  end

  before do
    3.times do
      project = create(:project, ngo: ngo, funding_target_cents: 100_000, estimated_annual_reach: 15_000)
      create(:contribution, :confirmed, campaign: create(:campaign, ngo: ngo, project: project),
                                        contributor: profile, amount_cents: 25_000)
    end
    sign_in
  end

  # A tabela de obras é a parte larga da tela, e é ela que rola por dentro em
  # vez de empurrar o corpo da página.
  it "fits the viewport at phone, tablet and desktop widths" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit investor_path

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  end

  it "shows the four headline numbers together" do
    visit investor_path

    aggregate_failures do
      expect(page).to have_text(I18n.t("investors.show.invested"))
      expect(page).to have_text(I18n.t("investors.show.active_projects"))
      expect(page).to have_text(I18n.t("investors.show.people_reached"))
      expect(page).to have_text(I18n.t("investors.show.multiplier"))
    end
  end
end
