import { Controller } from "@hotwired/stimulus"

// Submete o formulário sozinho enquanto a pessoa digita, com espera.
//
// Sem a espera, cada tecla vira um request e a lista pisca; com ela, a busca
// acontece quando a pessoa para. O `clearTimeout` no disconnect não é
// formalidade: sem ele um Turbo Visit que troque a página deixa o timer vivo,
// e ele submete um formulário que não está mais no documento.
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
