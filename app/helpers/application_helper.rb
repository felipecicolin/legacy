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
end
