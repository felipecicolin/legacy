# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection do
  it "identifies the user behind a valid session cookie" do
    session = create(:user).sessions.create!
    cookies.signed[:session_id] = session.id

    connect "/cable"

    expect(connection.current_user).to eq(session.user)
  end

  # O WebSocket usa a mesma sessão do HTTP: sem cookie válido não há conexão,
  # e não uma conexão anônima que os canais precisariam lembrar de checar.
  it "rejects a connection with no session" do
    expect { connect "/cable" }.to have_rejected_connection
  end
end
