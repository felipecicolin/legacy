# frozen_string_literal: true

require "rails_helper"

# O que este spec defende: um token renomeado ou removido não vira erro em lugar
# nenhum. A view continua pedindo `bg-primary`, o Tailwind simplesmente não gera
# mais a classe, e o elemento sai transparente — sem exceção, sem log, sem
# linter. Nenhuma ferramenta deste repositório lê o CSS compilado.
#
# Por isso a pergunta é feita ao navegador, com o CSS de verdade carregado, via
# `getComputedStyle`. E toda cor é sondada por `background-color`: é a única
# propriedade cujo default (`transparent`) prova ausência. `color` herda, então
# um `text-*` inexistente pegaria a cor do <body> e passaria no teste.
RSpec.describe "Design tokens" do
  before { visit "/rails/view_components/design_tokens/default" }

  # Um `evaluate_script` por mapa em vez de um por token: são 34 elementos, e
  # cada round trip com o chromedriver custa mais que a medição.
  let(:backgrounds) do
    page.evaluate_script(<<~JS)
      Object.fromEntries(Array.from(document.querySelectorAll("[data-token]"))
        .map((el) => [el.dataset.token, getComputedStyle(el).backgroundColor]))
    JS
  end

  let(:radii) do
    page.evaluate_script(<<~JS)
      Object.fromEntries(Array.from(document.querySelectorAll("[data-radius]"))
        .map((el) => [el.dataset.radius, getComputedStyle(el).borderTopLeftRadius]))
    JS
  end

  it "sonda todo token de cor declarado no tokens.css" do
    expect(backgrounds.keys).to match_array(DesignTokenManifest.colors)
  end

  it "sonda todo token de raio declarado no tokens.css" do
    expect(radii.keys).to match_array(DesignTokenManifest.radii)
  end

  it "resolve toda cor semântica para uma cor de verdade" do
    aggregate_failures do
      backgrounds.each do |token, color|
        expect(color).not_to eq("rgba(0, 0, 0, 0)"),
                             "bg-#{token} saiu transparente: a utility não foi gerada — token removido ou renomeado"
      end
    end
  end

  # Classe de raio inexistente não cai em transparente, cai em 0px — o default
  # do border-radius. É o mesmo silêncio, com outro valor.
  it "resolve todo raio semântico" do
    aggregate_failures do
      radii.each do |token, radius|
        expect(radius).not_to eq("0px"),
                              "rounded-#{token} saiu sem raio: a utility não foi gerada"
      end
    end
  end

  it "cumpre WCAG AA no texto de cada par semântico" do
    aggregate_failures do
      DesignTokenManifest.text_pairs.each do |front, back|
        ratio = WcagContrast.ratio(backgrounds.fetch(front), backgrounds.fetch(back))
        expect(ratio).to be >= WcagContrast::TEXT,
                         "#{front} sobre #{back} dá #{ratio}:1, abaixo de #{WcagContrast::TEXT}:1"
      end
    end
  end

  it "cumpre WCAG AA nas fronteiras de UI" do
    aggregate_failures do
      DesignTokenManifest::UI_PAIRS.each do |front, back|
        ratio = WcagContrast.ratio(backgrounds.fetch(front), backgrounds.fetch(back))
        expect(ratio).to be >= WcagContrast::UI,
                         "#{front} sobre #{back} dá #{ratio}:1, abaixo de #{WcagContrast::UI}:1"
      end
    end
  end
end
