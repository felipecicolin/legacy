# frozen_string_literal: true

# Ponto de chegada de quem acabou de entrar. O `after_authentication_url` cai
# em `root_url` quando não havia destino guardado, então sem uma rota raiz um
# login bem-sucedido levanta — a autenticação não fecha o ciclo sozinha.
#
# É um espaço reservado deliberadamente mínimo: #8 traz o shell de layout e
# #21 traz as rotas e os controllers de verdade. O que precisa sobreviver a
# essas duas issues é só a rota `root`.
class HomeController < ApplicationController
  # Espaço reservado: não há registro para autorizar até #8 trazer o shell.
  skip_authorization_for

  def show; end
end
