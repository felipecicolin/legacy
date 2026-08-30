# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  CLASS_MERGER = TailwindMerge::Merger.new

  attr_reader :html_options

  def initialize(**html_options)
    super()
    @html_options = html_options
  end

  # Identificador Stimulus do controller do componente. Espelha a chave que o
  # `pin_all_from "app/javascript/controllers", under: "controllers"` produz
  # para `app/javascript/controllers/<nome>_component_controller.js`, para o
  # template escrever `data: { controller: stimulus_controller }` sem nunca
  # soletrar o identificador.
  #
  # Não é sidecar dentro de app/components de propósito — ver o comentário em
  # config/application.rb sobre o Propshaft publicar os .rb.
  def stimulus_controller
    self.class.name.underscore.dasherize.gsub("/", "--")
  end

  # Compõe classes do Tailwind resolvendo conflitos: a última vence. Sem isso,
  # `class_merge("px-4", "px-6")` deixaria as duas na string e quem ganharia
  # seria a ordem no CSS compilado, não a intenção de quem chamou.
  def class_merge(*classes)
    CLASS_MERGER.merge(classes.compact.join(" "))
  end

  def validate_inclusion!(name, value, allowed)
    return if allowed.include?(value)

    raise ArgumentError,
          "#{self.class.name}: invalid #{name} #{value.inspect}. Allowed: #{allowed.inspect}"
  end
end
