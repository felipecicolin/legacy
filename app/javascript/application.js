// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// A ordem aqui é significativa. O `localizeTrix()` precisa rodar antes de o
// Trix definir o custom element `trix-editor` — ver app/javascript/trix_locale.js.
import "trix"
import { localizeTrix } from "trix_locale"
import "@rails/actiontext"

localizeTrix()
