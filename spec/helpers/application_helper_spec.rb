# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper do
  it "is mixed into the view context of every controller" do
    expect(ApplicationController.helpers).to be_a(described_class)
  end

  # Só apelidos semânticos: trocar a paleta em tokens.css não pode exigir uma
  # linha aqui, e é essa a promessa que a regra `no-color-scale-utility` cobra
  # nos templates e que nada cobraria numa string montada em Ruby.
  it "styles auth fields with semantic tokens only" do
    expect(helper.auth_field_classes).not_to match(/-(?:gray|blue|red|green|amber|slate)-\d{2,3}\b/)
  end

  it "borders auth fields with the input token, which owes 3:1" do
    expect(helper.auth_field_classes).to include("border-input")
  end
end
