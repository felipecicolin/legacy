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

  # Pares que não seguem a convenção `X` / `X-foreground`. `foreground` sobre
  # `background` é o texto corrido da aplicação, e as categóricas são lidas
  # como texto sobre o fundo da página.
  EXTRA_TEXT_PAIRS = [
    %w[foreground background],
    %w[category-1 background],
    %w[category-2 background],
    %w[category-3 background],
    %w[category-4 background],
  ].freeze

  # `input` é a fronteira de um campo — componente de UI pela 1.4.11, e não
  # texto. `border` fica de fora: divisória decorativa, que a regra não alcança.
  UI_PAIRS = [%w[input background]].freeze

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
    filled + soft + EXTRA_TEXT_PAIRS
  end
end
