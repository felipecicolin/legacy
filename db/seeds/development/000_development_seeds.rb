# frozen_string_literal: true

# As camadas do seed de desenvolvimento. Cada arquivo deste diretório apenas
# DEFINE um módulo com `load!`; quem invoca é o `db/seeds.rb`.
#
# A separação não é cerimônia: com a chamada dentro do arquivo, carregá-lo para
# inspecionar — num spec, no console — já gravaria no banco. Definição pura é
# carregável sem efeito.
module DevelopmentSeeds
  module_function

  # Ordem alfabética dos módulos, e não a ordem em que o Ruby devolve
  # `constants`: as camadas dependem umas das outras (obra precisa de base), e
  # o prefixo numérico do arquivo é o que declara essa ordem.
  def load_all!
    layers.each(&:load!)
  end

  def layers
    constants.sort.map { |name| const_get(name) }.select { |layer| layer.respond_to?(:load!) }
  end
end
