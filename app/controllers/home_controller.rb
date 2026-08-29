# frozen_string_literal: true

# Ponto de chegada de quem acabou de entrar. O `after_authentication_url` cai
# em `root_url` quando não havia destino guardado, então sem uma rota raiz um
# login bem-sucedido levanta — a autenticação não fecha o ciclo sozinha.
#
# É um espaço reservado deliberadamente mínimo: #8 traz o shell de layout e
# #57 traz as rotas e os controllers de verdade. O que precisa sobreviver a
# essas duas issues é só a rota `root`.
class HomeController < ApplicationController
  def show; end
end
