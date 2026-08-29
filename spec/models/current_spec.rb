# frozen_string_literal: true

require "rails_helper"

RSpec.describe Current do
  it "exposes the user behind the current session" do
    session = create(:user).sessions.create!

    described_class.session = session

    expect(described_class.user).to eq(session.user)
  end

  # O `allow_nil: true` do delegate é o que segura a página pública: sem
  # sessão, perguntar pelo usuário devolve nil em vez de levantar.
  it "answers nil for the user when there is no session" do
    described_class.session = nil

    expect(described_class.user).to be_nil
  end
end
