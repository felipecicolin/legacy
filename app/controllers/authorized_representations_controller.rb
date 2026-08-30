# frozen_string_literal: true

# O mesmo que `AuthorizedBlobsController`, para as rotas de variante — que são
# as que uma `<img>` de galeria realmente pede (ver `ImageFrameComponent`).
class AuthorizedRepresentationsController < ActiveStorage::Representations::ProxyController
  include Authentication
  include AuthorizedBlobDelivery

  allow_unauthenticated_access

  # A ordem importa e por isso o callback herdado é reposicionado: como está
  # declarado na classe-mãe, `set_representation` correria ANTES da
  # autorização, e ele PROCESSA a variante — quem não pode ver o arquivo teria
  # mandado a aplicação abrir, redimensionar e gravar uma cópia dele antes de
  # levar o 404. Removido e redeclarado, ele passa a correr depois.
  skip_before_action :set_representation
  before_action :set_representation
end
