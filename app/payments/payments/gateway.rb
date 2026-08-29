# frozen_string_literal: true

module Payments
  # A fronteira. Modelo, controller, job e view falam com este objeto, e nunca
  # com o provedor — é isso que permite trocar o simulador por um gateway real
  # reapontando `config.x.payment_provider`, sem tocar em domínio e sem
  # migration.
  #
  # Toda chamada vira linha em `payment_transactions`, com a marca de origem
  # que o próprio provedor declara. Registrar aqui, e não em cada chamador, é o
  # que sustenta a promessa de não existir movimento de dinheiro sem rastro —
  # e de nenhuma tela precisar perguntar "isto é demo?" para saber se marca.
  class Gateway
    def self.simulated?
      new.simulated?
    end

    def initialize(provider: Rails.application.config.x.payment_provider)
      @provider = provider
    end

    delegate :simulated?, to: :@provider

    def charge(request) = execute(:charge, request)

    def refund(request) = execute(:refund, request)

    def schedule_recurring(request) = execute(:schedule_recurring, request)

    private

    def execute(operation, request)
      result = @provider.public_send(operation, request)
      PaymentTransaction.create!(ledger_attributes(operation, request, result))
    end

    def ledger_attributes(operation, request, result)
      request.to_h.merge(kind: operation, simulated: @provider.simulated?, status: result.status,
                         provider_reference: result.reference, processed_at: result.processed_at,
                         failure_reason: result.failure_reason)
    end
  end
end
