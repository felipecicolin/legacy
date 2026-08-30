# frozen_string_literal: true

# Campo de escolha para barra de filtro.
#
# Não é o `InputComponent`: aquele recebe o form builder de um OBJETO e lê
# `errors` e `human_attribute_name` dele. Filtro de busca não tem objeto — o
# formulário é um `form_with url:` —, e passar um objeto falso só para
# satisfazer a API seria inventar um registro que não existe.
class SelectComponent < ApplicationComponent
  SELECT_CLASSES = "mt-1 block min-h-11 w-full rounded-sm border border-input bg-background px-3 py-2 " \
                   "text-body text-foreground focus-visible:outline-none focus-visible:ring-2 " \
                   "focus-visible:ring-ring focus-visible:ring-offset-2"

  Attrs = Data.define(:name, :label, :choices, :selected, :include_blank)
  private_constant :Attrs

  def initialize(name:, label:, choices:, selected: nil, include_blank: nil, **html_options)
    @attrs = Attrs.new(name: name, label: label, choices: choices, selected: selected,
                       include_blank: include_blank)
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: class_merge("block", html_options[:class]))
  end

  # O `<select>` vive DENTRO do `<label>`: a associação fica implícita e não
  # depende de alguém lembrar de casar `for` com `id`. Placeholder não é label,
  # e aqui não há placeholder nenhum para confundir com um.
  def select_tag
    helpers.select_tag(@attrs.name, option_tags, class: SELECT_CLASSES,
                                                 include_blank: @attrs.include_blank)
  end

  def option_tags
    helpers.options_for_select(@attrs.choices, @attrs.selected)
  end

  delegate :label, to: :@attrs
end
