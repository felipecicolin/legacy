# frozen_string_literal: true

require "rails_helper"

# O split só existe depois que o CSS resolve: `w-1/2`, `flex-row-reverse` e o
# `desktop:block` do painel são decisões do navegador, e nenhuma delas aparece
# num spec de componente — lá o que existe é a string de classes.
RSpec.describe "Authentication split layout" do
  def body_fits?
    page.evaluate_script("document.body.scrollWidth <= document.documentElement.clientWidth")
  end

  def panel_visible?
    page.evaluate_script("document.querySelector('aside').getBoundingClientRect().width > 0")
  end

  before { visit "/rails/view_components/auth_layout_component/default" }

  after { page.current_window.resize_to(1400, 1400) }

  it "fits the viewport at phone, tablet and desktop widths" do
    aggregate_failures do
      [375, 768, 1440].each do |width|
        page.current_window.resize_to(width, 900)
        visit "/rails/view_components/auth_layout_component/default"

        expect(body_fits?).to be(true), "body rolou na horizontal em #{width}px"
      end
    end
  end

  # Abaixo de 1024px o painel some e o formulário fica com a tela inteira: um
  # decorativo espremido empurraria o formulário para baixo da dobra.
  it "hides the image panel below the desktop breakpoint" do
    page.current_window.resize_to(768, 900)
    visit "/rails/view_components/auth_layout_component/default"

    expect(panel_visible?).to be(false)
  end

  it "paints the image panel on the left half at desktop width" do
    page.current_window.resize_to(1440, 900)
    visit "/rails/view_components/auth_layout_component/default"

    panel = page.evaluate_script("document.querySelector('aside').getBoundingClientRect().left")
    form = page.evaluate_script("document.querySelector('main').getBoundingClientRect().left")
    expect(panel).to be < form
  end
end
