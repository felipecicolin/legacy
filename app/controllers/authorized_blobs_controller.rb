# frozen_string_literal: true

# Quem responde pelas rotas de blob do Active Storage. O `config/routes.rb`
# declara os mesmos padrões ANTES de o engine declarar os dele, e o roteador
# casa em ordem — os helpers (`rails_blob_path` e companhia) continuam sendo os
# do engine e continuam gerando as mesmas URLs, mas quem atende é isto aqui.
#
# Herda do controller de PROXY, e não do de redirect, mesmo nas rotas de
# redirect: redirecionar entregaria uma URL assinada do serviço de storage, que
# vale por si e não passa por autorização nenhuma. Fazendo streaming, a
# autorização acontece em toda requisição do arquivo, não só na primeira.
class AuthorizedBlobsController < ActiveStorage::Blobs::ProxyController
  include Authentication
  include AuthorizedBlobDelivery

  # Foto de obra pública é vitrine e não pede login. Quem decide é a política
  # de visibilidade, que a partir daqui responde no contexto anônimo.
  allow_unauthenticated_access
end
