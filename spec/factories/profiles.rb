# frozen_string_literal: true

FactoryBot.define do
  factory :profile do
    user

    # Sequência no nome legal para que dois perfis no mesmo exemplo sejam
    # distinguíveis na mensagem de falha. `display_name` fica de fora de
    # propósito: o default dele é comportamento sob teste.
    sequence(:legal_name) { |n| "Maria de Souza #{n}" }
  end
end
