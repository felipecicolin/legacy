# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      identify_user || reject_unauthorized_connection
    end

    private

    # Mesma sessão do HTTP: o cookie guarda o id da linha em `sessions`, então
    # encerrar a sessão pela web também derruba o WebSocket.
    def identify_user
      session = Session.find_by(id: cookies.signed[:session_id])
      self.current_user = session.user if session
    end
  end
end
