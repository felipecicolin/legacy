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
  #
  # O alcance exato, porque metade dele é contraintuitivo: `update`, `update!`,
  # `save` e `update_column` levantam. `update_all` e SQL cru **não** — os dois
  # montam o UPDATE sem passar pelo registro, e nenhum callback ou validação
  # roda no caminho. Um script de correção em massa escrito com `update_all`
  # promove a coluna inteira em silêncio. A trava no banco que pegaria isso é
  # trigger, não `CHECK`, e ela não caberia aqui — ver `docs/payments.md`.
  attr_readonly :simulated

  # Os dois vocabulários vêm do contrato, não de uma segunda lista aqui: o
  # provedor e a tabela discordarem sobre o que é uma situação válida é a
  # divergência que aparece tarde, num relatório que soma errado.
  enum :kind, Payments::PaymentProvider::OPERATIONS.index_with(&:to_s)
  enum :status, Payments::PaymentProvider::STATUSES.index_with(&:to_s)

  # Nenhum valor de enum vai cru para a tela — a convenção é `<enum no
  # plural>.<valor>` no topo do locale, e está em `docs/i18n.md`.
  #
  # `scope:` com o valor em variável, e não `t("kinds.#{...}")`: o cop
  # `I18n/RailsI18n/DecorateStringFormattingUsingInterpolation` proíbe
  # interpolação dentro da chave.
  #
  # O scanner do i18n-tasks não resolve chave montada assim e acusaria os sete
  # rótulos como órfãos. Quem responde por eles é o
  # `spec/models/enum_translation_audit_spec.rb` — ver a nota em
  # `config/i18n-tasks.yml.erb`.
  def kind_label
    I18n.t(kind, scope: :kinds)
  end

  def status_label
    I18n.t(status, scope: :statuses)
  end

  validates :kind, :status, :reference, :provider_reference, :currency, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # ISO 4217 e nada mais. A coluna existe para que a soma de valores em moedas
  # diferentes seja impossível de fazer por acidente. O formato vem do contrato,
  # que é quem o `Payments::Request` também consulta.
  validates :currency, format: { with: Payments::PaymentProvider::CURRENCY_FORMAT }

  # `presence` reprovaria `false`, que é um valor legítimo. O que se cobra aqui
  # é que a coluna esteja decidida — nunca `nil`.
  validates :simulated, inclusion: { in: [true, false] }
end
