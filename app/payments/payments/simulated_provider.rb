# frozen_string_literal: true

module Payments
  # O único provedor que existe hoje, e o motivo de este repositório não ter
  # gateway, chave de API nem webhook: a demo mostra o domínio de arrecadação
  # inteiro sem que um centavo real — ou um dado de instrumento de pagamento —
  # chegue perto do banco.
  #
  # Determinístico: o desfecho é o que a configuração disser, igual em toda
  # chamada. Sem sorteio, por dois motivos. Uma demo que falha uma vez a cada
  # dez não dá para apresentar, e um spec sobre ela seria intermitente.
  #
  # Configurável: `outcome:` produz sucesso, pendência, falha e recusa. Uma
  # demo que só mostra o caminho feliz não prova que a UI trata erro.
  class SimulatedProvider
    include PaymentProvider

    # O prefixo entra na referência devolvida para que a marca de simulação
    # sobreviva à tela: quem lê só o comprovante, o relatório ou a linha do
    # banco vê `SIM-` antes de ver qualquer valor.
    PREFIXES = { charge: "SIM", refund: "SIM-REF", schedule_recurring: "SIM-REC" }.freeze

    # Código, não frase — a tradução é da view. Sucesso e pendência não têm
    # motivo, e a ausência aqui é o `nil` que o `Result` espera.
    FAILURE_REASONS = { failed: "provider_unavailable", refused: "not_authorized" }.freeze

    def initialize(outcome: :succeeded)
      raise ArgumentError, "unknown outcome #{outcome.inspect}" unless PaymentProvider::STATUSES.include?(outcome)

      @outcome = outcome
    end

    def simulated?
      true
    end

    def charge(request) = simulate(:charge, request)

    def refund(request) = simulate(:refund, request)

    def schedule_recurring(request) = simulate(:schedule_recurring, request)

    private

    def simulate(operation, request)
      Result.new(status: @outcome, reference: "#{PREFIXES.fetch(operation)}-#{request.reference}",
                 processed_at: settled_at, failure_reason: FAILURE_REASONS[@outcome])
    end

    # Pendência é justamente o que ainda não foi processado: datar o que não
    # aconteceu faria a tela mostrar um horário de liquidação inventado.
    def settled_at
      @outcome == :pending ? nil : Time.current
    end
  end
end
