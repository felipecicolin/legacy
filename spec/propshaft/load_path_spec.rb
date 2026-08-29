# frozen_string_literal: true

require "rails_helper"

# O que este spec defende: nenhum caminho lógico do Propshaft é reivindicado por
# dois arquivos.
#
# O `Propshaft::LoadPath` monta o mapa com `mapped[caminho_lógico] ||= …`, então
# quando dois arquivos disputam o mesmo nome quem vence é a ORDEM do
# `config.assets.paths` — e essa ordem não é a mesma em toda máquina. Foi
# exatamente o que derrubou a #32: `vendor/javascript/trix.js` (o build ESM,
# baixado) e o `trix.js` da gem `action_text-trix` (o build UMD) disputavam
# `trix.js`. Na máquina de quem escreveu, o vendor ganhava; no runner do GitHub,
# a gem. E o UMD não tem `export default`, então o `import Trix from "trix"`
# falhava na LIGAÇÃO do módulo — o que rejeita o grafo inteiro. Resultado no
# navegador: todo módulo baixado com 200 e nenhum avaliado. Sem Turbo, sem
# Stimulus, sem Trix, e sem erro em lugar nenhum que uma ferramenta lesse.
#
# É a família "ferramenta que falha em silêncio" do AGENTS.md: nem o
# `assets:precompile`, nem o `bin/importmap audit`, nem o `bin/stimulus_lint`
# dizem uma palavra sobre nome duplicado. Este spec diz. Ver
# docs/action-text.md.
RSpec.describe Propshaft::LoadPath do
  def asset_roots
    Rails.application.assets.load_path.paths.select(&:exist?)
  end

  # O mesmo filtro do `without_dotfiles` do Propshaft: arquivo que começa com
  # ponto (`.keep`) não vira asset, e cobrá-lo aqui acusaria colisão que o
  # Propshaft nunca teria.
  def asset_files_in(root)
    root.glob("**/*").reject { |file| file.directory? || file.basename.to_s.start_with?(".") }
  end

  def claimants_by_logical_path
    asset_roots.each_with_object(Hash.new { |claims, name| claims[name] = [] }) do |root, claims|
      asset_files_in(root).each { |file| claims[file.relative_path_from(root).to_s] << file.to_s }
    end
  end

  def report(ambiguous)
    ambiguous.map { |name, files| "#{name} vem de:\n  #{files.join("\n  ")}" }
             .join("\n").prepend("Caminho lógico disputado — quem vence depende da máquina:\n")
  end

  it "não deixa dois arquivos reivindicarem o mesmo caminho lógico" do
    ambiguous = claimants_by_logical_path.select { |_, files| files.size > 1 }

    expect(ambiguous).to be_empty, -> { report(ambiguous) }
  end
end
