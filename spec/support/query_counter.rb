# frozen_string_literal: true

# Conta as queries de um bloco.
#
# `SCHEMA` e `TRANSACTION` ficam de fora de propósito: a primeira consulta de um
# modelo carrega as colunas, e cada exemplo abre e fecha a transação da fixture.
# Nenhuma das duas depende de quantos registros a listagem tem, mas as duas
# fazem a contagem oscilar entre uma medição e outra — e é a comparação entre
# duas medições que prova ausência de N+1.
module QueryCounter
  UNCOUNTED = %w[SCHEMA TRANSACTION].freeze

  def count_queries(&)
    queries = []
    collect = ->(*, payload) { queries << payload unless uncounted?(payload) }
    ActiveSupport::Notifications.subscribed(collect, "sql.active_record", &)
    queries.size
  end

  private

  def uncounted?(payload)
    payload[:cached] || UNCOUNTED.include?(payload[:name])
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
