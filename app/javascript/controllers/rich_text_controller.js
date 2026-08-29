import { Controller } from "@hotwired/stimulus"

// Recusa anexo embutido no editor de texto rico.
//
// O `trix-file-accept` é o único ponto por onde um arquivo entra no Trix —
// botão de anexar, arrastar e soltar, e colar do clipboard passam todos por
// ele. Cancelar o evento fecha os três de uma vez, antes de existir upload.
//
// Este é o lado do navegador da política; o lado que vale é o do servidor, no
// config/initializers/action_text.rb. Ver docs/action-text.md.
export default class extends Controller {
  rejectAttachment(event) {
    event.preventDefault()
  }
}
