# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Action Text. O `actiontext.esm.js` sai do asset path da própria gem; o `trix`
# é npm e está BAIXADO em vendor/javascript, não apontado para a CDN — todo JS
# que este projeto serve vem do próprio domínio, e um editor que some porque um
# CDN de terceiro caiu é um jeito caro de descobrir a dependência.
pin "trix" # @2.1.19
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "trix_locale"
