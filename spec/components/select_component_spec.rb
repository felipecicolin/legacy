# frozen_string_literal: true

require "rails_helper"

RSpec.describe SelectComponent, type: :component do
  let(:choices) { [["Em obra", "in_progress"], ["Parada", "paused"]] }

  def render_select(**)
    render_inline(described_class.new(name: :status, label: "Situação", choices: choices, **))
  end

  it "renders every choice it was given" do
    render_select

    expect(page).to have_css("option", count: choices.size)
  end

  # O `<select>` vive DENTRO do `<label>`: a associação fica implícita e não
  # depende de alguém casar `for` com `id`. É o que faz o leitor de tela
  # anunciar o campo pelo nome certo.
  it "wraps the field in its own label" do
    render_select

    expect(page).to have_css("label select[name='status']")
  end

  it "marks the choice that is already made" do
    render_select(selected: "paused")

    expect(page).to have_css("option[selected][value='paused']")
  end

  it "offers a blank option when one is asked for" do
    render_select(include_blank: "Qualquer uma")

    expect(page).to have_css("option", text: "Qualquer uma")
  end

  it "leaves the blank option out when it is not" do
    render_select

    expect(page).to have_no_css("option[value='']")
  end

  it "keeps the classes it was handed" do
    render_select(class: "desktop:col-span-2")

    expect(page).to have_css("label.desktop\\:col-span-2")
  end
end
