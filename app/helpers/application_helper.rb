# frozen_string_literal: true

module ApplicationHelper
  # As cinco entradas das telas de autenticação usam a mesma aparência, e ela
  # ainda não tem componente: o `InputComponent` é a #14. Uma constante aqui é
  # o menor lugar honesto para a string até lá — copiada em cinco views, a
  # próxima mudança de estilo esqueceria uma.
  #
  # `border-input` e não `border-border`: a fronteira de um campo é componente
  # de UI pela WCAG 1.4.11 e precisa de 3:1, que a divisória decorativa não dá.
  AUTH_FIELD_CLASSES = "mt-2 block w-full rounded-sm border border-input bg-card px-3 py-2 " \
                       "text-foreground placeholder:text-muted-foreground " \
                       "focus:outline-none focus:ring-2 focus:ring-ring"

  def auth_field_classes
    AUTH_FIELD_CLASSES
  end

  # Dinheiro é `bigint` de centavos, e a divisão por 100 tem de acontecer num
  # lugar só: espalhada pelas views, a próxima tela erra a escala em cem vezes
  # e ninguém percebe até alguém conferir um extrato. Ver docs/payments.md.
  #
  # A unidade sai do locale, e não de uma string aqui: hoje toda coluna de
  # moeda deste repositório nasce `BRL`.
  def money_from_cents(cents)
    number_to_currency(cents.to_i / 100.0)
  end

  # Sem centavos: num cartão comparativo os dois últimos dígitos nunca mudam a
  # decisão e roubam a largura de que o rótulo precisa.
  def money_rounded_from_cents(cents)
    number_to_currency(cents.to_i / 100.0, precision: 0)
  end

  # Percentual de um par valor/meta, protegido contra meta zerada — que é
  # legítima aqui: obra sem orçamento aprovado ainda não tem denominador.
  def share_percentage(value, target)
    return 0 if target.to_i.zero?

    ((value.to_f / target) * 100).clamp(0, 100).round
  end
end
