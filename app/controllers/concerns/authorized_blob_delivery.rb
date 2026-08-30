# frozen_string_literal: true

# Entrega de arquivo autorizada pela mesma política que decide o resto.
#
# Os controllers do Active Storage são públicos por padrão — o próprio comentário
# deles diz isso — e a única proteção nativa é a URL ser difícil de adivinhar.
# Para foto de obra confidencial isso não serve: a URL é permanente, viaja em
# print, em e-mail encaminhado e em cache de proxy. Ver docs/photo-policy.md.
module AuthorizedBlobDelivery
  extend ActiveSupport::Concern

  # Sessão aberta ainda não diz QUANTO a pessoa alcança: papel é contexto, e as
  # tabelas que o guardam chegam em #20, #21 e #31. Até lá o teto de quem
  # entrou é `restricted`, e `confidential` não é alcançável por esta porta —
  # o que é o lado seguro do erro.
  SIGNED_IN_CLEARANCE = :restricted

  included do
    before_action :require_visible_blob
  end

  private

  def visibility_context
    return Visibility::Context.anonymous unless authenticated?

    Visibility::Context.new(clearance: SIGNED_IN_CLEARANCE)
  end

  # 404, e não 403: um 403 confirma que o arquivo existe, e a existência de uma
  # foto já é informação sobre a obra. É a mesma escolha do login, que não diz
  # se a conta existe.
  def require_visible_blob
    head :not_found unless blob_visible?
  end

  # `all?`, e não `any?`: um mesmo blob pode estar anexado a mais de um
  # registro, e basta um deles fora do alcance para a entrega ser negada.
  # Sobre coleção vazia `all?` é verdadeiro — blob órfão segue como antes.
  #
  # Registro que não declara sensibilidade não é alcançado por esta política, e
  # o limite está escrito no doc: quem quiser a garantia inclui `Sensitive`.
  def blob_visible?
    context = visibility_context

    @blob.attachments.all? do |attachment|
      record = attachment.record

      !record.is_a?(Sensitive) || context.can_see_attachment?(record)
    end
  end
end
