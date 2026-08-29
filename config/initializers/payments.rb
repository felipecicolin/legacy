# frozen_string_literal: true

# A única linha do repositório que nomeia um provedor concreto.
#
# Todo o resto — modelo, controller, view, componente — fala com
# `Payments::Gateway`, que lê daqui. Trocar o simulador por um gateway de
# verdade é reescrever esta atribuição, e nada mais.
#
# `to_prepare` e não atribuição direta porque a classe é autoloaded: uma
# instância guardada no corpo do initializer ficaria pendurada numa versão
# antiga da classe depois do primeiro reload em desenvolvimento, e o objeto
# vivo deixaria de ser o código do arquivo.
#
# `PAYMENT_OUTCOME` troca o desfecho do simulador sem tocar em código — é assim
# que a demo mostra a tela de pendência, a de falha e a de recusa, e não só a
# do caminho feliz. Não é chave, não é segredo: não há terceiro do outro lado.
Rails.application.config.to_prepare do
  outcome = ENV.fetch("PAYMENT_OUTCOME", "succeeded").to_sym
  Rails.application.config.x.payment_provider = Payments::SimulatedProvider.new(outcome: outcome)
end
