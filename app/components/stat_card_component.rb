# frozen_string_literal: true

# Um número de destaque, com o que ele é em cima e a unidade embaixo.
#
# Componente e não markup repetido: os mesmos quatro cartões aparecem em duas
# dashes, e a hierarquia deles — rótulo pequeno, número grande, dica discreta —
# é o que faz a leitura acontecer em um golpe de vista.
class StatCardComponent < ApplicationComponent
  def initialize(label:, value:, hint: nil, **html_options)
    @label = label
    @value = value
    @hint = hint
    super(**html_options)
  end

  attr_reader :label, :value, :hint

  def html_attributes
    html_options.merge(class: computed_classes)
  end

  private

  def computed_classes
    class_merge("rounded-lg border border-border bg-card p-5", html_options[:class])
  end
end
