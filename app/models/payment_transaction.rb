# frozen_string_literal: true

# O rastro de todo movimento de dinheiro — hoje simulado, amanhã real.
#
# É esta tabela que faz "trocar o adaptador não pede migration" ser verdade: as
# colunas descrevem o que qualquer provedor devolve (situação, comprovante,
# horário, motivo da recusa), e não o que um provedor específico cobra para
# processar. Não há aqui número, validade, código de segurança nem titular:
# a demo não coleta o que a demo não usa, e o que não é coletado não vaza.
class PaymentTransaction < ApplicationRecord
  # A marca de origem é gravada uma vez e nunca mais. Com o default 8.1, o
  # `attr_readonly` levanta `ActiveRecord::ReadonlyAttributeError` na
  # atribuição em registro já persistido — então promover um lançamento
  # simulado a real não é um update a ser revisado em code review: é uma
  # exceção, em tempo de execução, no lugar onde alguém tentou.
  attr_readonly :simulated

  # Os dois vocabulários vêm do contrato, não de uma segunda lista aqui: o
  # provedor e a tabela discordarem sobre o que é uma situação válida é a
  # divergência que aparece tarde, num relatório que soma errado.
  enum :kind, Payments::PaymentProvider::OPERATIONS.index_with(&:to_s)
  enum :status, Payments::PaymentProvider::STATUSES.index_with(&:to_s)

  validates :kind, :status, :reference, :provider_reference, :currency, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # ISO 4217 e nada mais. A coluna existe para que a soma de valores em moedas
  # diferentes seja impossível de fazer por acidente.
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }

  # `presence` reprovaria `false`, que é um valor legítimo. O que se cobra aqui
  # é que a coluna esteja decidida — nunca `nil`.
  validates :simulated, inclusion: { in: [true, false] }
end
