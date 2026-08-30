# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Action Text. Os três saem do asset path de uma gem — nada de CDN: todo JS que
# este projeto serve vem do próprio domínio.
#
# O `trix.js` é o da gem `action_text-trix`, dependência transitiva da
# `actiontext` e travada por ela (`~> 2.1.15`). NÃO baixe uma segunda cópia para
# `vendor/javascript/`: duas cópias disputam o caminho lógico `trix.js`, e quem
# vence depende da ordem do `config.assets.paths`, que muda de máquina para
# máquina. Quem cobra é `spec/propshaft/load_path_spec.rb`.
#
# A cópia da gem é UMD: ela define `window.Trix` e não exporta nada. Por isso
# `import "trix"` (efeito colateral) e nunca `import Trix from "trix"` — ver
# app/javascript/trix_locale.js.
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "trix_locale"

# ApexCharts, servido do PRÓPRIO domínio como todo o resto: a cópia está em
# `vendor/javascript/apexcharts.js`, baixada uma vez. Pinar para CDN
# economizaria 560 KB do repositório e entregaria o JS da aplicação a partir de
# um domínio que não é nosso — a mesma razão pela qual o Trix vem da gem.
#
# É a build ESM (`export default`), então `import ApexCharts from "apexcharts"`.
# A UMD definiria `window.ApexCharts` e o import quebraria o grafo inteiro em
# silêncio — a armadilha que o `trix` já custou aqui.
pin "apexcharts"
