# frozen_string_literal: true

# Lê o `@theme inline` do tokens.css e devolve os nomes declarados.
#
# O spec de sistema compara esta lista com o que a página de fumaça mostra, e é
# esse cruzamento que fecha o buraco: sondar só o que a página lista deixaria um
# token novo passar despercebido, e listar os tokens no spec à mão criaria uma
# segunda cópia da verdade para envelhecer.
module DesignTokenManifest
  module_function

  THEME_BLOCK = /@theme inline \{(.+?)\n\}/m

  # Pares de texto que não seguem a convenção `X` / `X-foreground`:
  # `foreground` é o texto corrido sobre o fundo da página, e
  # `muted-foreground` sobre o mesmo fundo é o uso real do texto de apoio —
  # mais comum que o par `muted-foreground` / `muted`, que a convenção deriva.
  EXTRA_TEXT_PAIRS = [
    %w[foreground background],
    %w[muted-foreground background],
  ].freeze

  # Toda categórica é lida como texto sobre o fundo da página. Derivadas, e não
  # listadas, para que `category-5` entre coberta sem ninguém lembrar de voltar
  # aqui — que é o que a receita em docs/design-system/tokens.md promete.
  CATEGORICAL = /\Acategory-/

  # Componentes de UI pela 1.4.11, que exige 3:1 e não os 4.5:1 de texto:
  # `input` é a fronteira de um campo e `ring` é o indicador de foco — o anel
  # que some no fundo deixa quem navega por teclado sem saber onde está.
  # `border` fica de fora de propósito: divisória decorativa, fora do alcance
  # da regra.
  UI_PAIRS = [
    %w[input background],
    %w[ring background],
  ].freeze

  def declarations
    Rails.root.join("app/assets/tailwind/tokens.css").read[THEME_BLOCK, 1].to_s
  end

  def colors
    declarations.scan(/--color-([\w-]+):/).flatten
  end

  def radii
    declarations.scan(/--radius-([\w-]+):/).flatten
  end

  # Cada `X` com um `X-foreground` é um par preenchido; cada `X` com um
  # `X-soft` é o par suave. Derivar em vez de listar mantém par novo coberto
  # sem ninguém lembrar de vir aqui.
  def text_pairs
    names = colors
    filled = names.filter_map { |name| ["#{name}-foreground", name] if names.include?("#{name}-foreground") }
    soft = names.filter_map { |name| [name, "#{name}-soft"] if names.include?("#{name}-soft") }
    filled + soft + names.grep(CATEGORICAL).map { |name| [name, "background"] } + EXTRA_TEXT_PAIRS
  end
end
