# frozen_string_literal: true

require "rails_helper"

# O que este spec defende: as duas decisões da #32 que vivem no navegador não
# têm linter. O `bin/stimulus_lint` não lê o Trix, o `bin/herb_lint` não lê CSS
# compilado, e `Trix.config.lang` aplicado tarde demais não levanta erro nenhum
# — só devolve a barra em inglês. A única pergunta honesta é a que se faz ao
# Chrome, com o JavaScript e o CSS de verdade carregados.
RSpec.describe "Editor de texto rico" do
  before { visit "/rails/view_components/rich_text_editor/default" }

  # `evaluate_script` porque a política vive num handler de evento: só um evento
  # de verdade, cancelável, responde se ela está ligada.
  let(:attachment_rejected) do
    page.evaluate_script(<<~JS)
      (() => {
        const editor = document.querySelector("trix-editor")
        const event = new CustomEvent("trix-file-accept", { bubbles: true, cancelable: true })
        editor.dispatchEvent(event)
        return event.defaultPrevented
      })()
    JS
  end

  it "sobe o editor" do
    expect(page).to have_css("trix-editor")
  end

  it "traduz a barra de ferramentas para pt-BR" do
    expect(page).to have_css("trix-toolbar button[title='Negrito']")
  end

  # O contraponto do exemplo acima: um `Object.assign` que rodasse tarde demais
  # deixaria os dois títulos convivendo, e só este exemplo notaria.
  it "não deixa rótulo em inglês na barra" do
    expect(page).to have_no_css("trix-toolbar button[title='Bold']", visible: :all)
  end

  it "não oferece o botão de anexar" do
    expect(page).to have_no_css("[data-trix-action='attachFiles']")
  end

  # Prova que o exemplo acima mede o que diz medir: o botão continua no DOM que
  # o Trix gera, e quem o tira de vista é o CSS do projeto.
  it "esconde o botão de anexar em vez de o Trix não o gerar" do
    expect(page).to have_css("[data-trix-action='attachFiles']", visible: :hidden)
  end

  it "recusa o anexo que chega pelo trix-file-accept" do
    expect(attachment_rejected).to be(true)
  end
end
