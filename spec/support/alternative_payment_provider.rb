# frozen_string_literal: true

# Um segundo provedor, que existe só para os specs.
#
# É ele que prova a promessa da #38: trocar de provedor é reapontar
# `config.x.payment_provider`, sem tocar em modelo, controller, view ou
# migration. Se algum dia esta classe precisar de uma coluna nova para caber na
# tabela, a fronteira vazou — e o spec que a usa é onde isso aparece.
#
# `simulated?` é `false` de propósito: além da troca, ele cobre o outro lado do
# `render?` do banner, que é o comportamento de uma instalação de verdade.
class AlternativePaymentProvider
  include Payments::PaymentProvider

  def simulated?
    false
  end

  def charge(request)
    Payments::Result.new(status: :succeeded, reference: "ALT-#{request.reference}",
                         processed_at: Time.current, failure_reason: nil)
  end
end
