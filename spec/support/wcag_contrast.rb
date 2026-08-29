# frozen_string_literal: true

# Razão de contraste da WCAG 2.1, sobre a cor que o NAVEGADOR resolveu.
#
# Existe para que a tabela de contraste no fim do `tokens.css` seja verificada
# em vez de anotada: um comentário com a razão medida envelhece no primeiro
# ajuste de primitiva, e ninguém percebe. O spec de sistema recalcula a partir
# do `getComputedStyle`, então o número não tem como divergir do que a tela
# mostra.
module WcagContrast
  module_function

  # Limiares da 1.4.3 (texto corrido) e da 1.4.11 (fronteira de UI).
  TEXT = 4.5
  UI = 3.0

  def ratio(first_rgb, second_rgb)
    lighter, darker = [relative_luminance(first_rgb), relative_luminance(second_rgb)].minmax.reverse
    ((lighter + 0.05) / (darker + 0.05)).round(2)
  end

  def relative_luminance(rgb)
    red, green, blue = channels(rgb).map { |channel| linearize(channel) }
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end

  # Aceita o `rgb(r, g, b)` e o `rgba(r, g, b, a)` que o getComputedStyle
  # devolve. O alfa é descartado: todo par medido aqui é opaco sobre opaco.
  def channels(rgb)
    rgb.scan(/\d+(?:\.\d+)?/).first(3).map { |value| value.to_f / 255 }
  end

  def linearize(channel)
    channel <= 0.03928 ? channel / 12.92 : (((channel + 0.055) / 1.055)**2.4)
  end
end
