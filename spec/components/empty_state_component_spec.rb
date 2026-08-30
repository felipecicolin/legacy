# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  it "renders the icon and title without optional content" do
    render_inline(described_class.new(icon: "blueprint", title: "Nenhuma obra cadastrada ainda"))

    expect(page).to have_css("section svg[aria-hidden='true']")
    expect(page).to have_css("section h2", text: "Nenhuma obra cadastrada ainda")
    expect(page).to have_no_css("section p")
  end

  it "renders a description and action slot" do
    render_inline(described_class.new(icon: "blueprint", title: "Sem acesso",
                                      description: "Você não tem acesso a esta região.")) do |state|
      state.with_action { "Solicitar acesso" }
    end

    expect(page).to have_css("section p", text: "Você não tem acesso a esta região.")
    expect(page).to have_css("section div", text: "Solicitar acesso")
  end

  it "lets caller classes replace the default surface spacing" do
    render_inline(described_class.new(icon: "blueprint", title: "Vazio", class: "p-6"))

    classes = page.find("section")[:class].split
    expect(classes).to include("p-6")
    expect(classes).not_to include("p-10")
  end
end
