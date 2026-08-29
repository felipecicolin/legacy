import { Controller } from "@hotwired/stimulus"

// Imagem que falha ao carregar mostra o ícone quebrado do navegador — que não
// é neutro, não é tokenizado e muda de desenho a cada navegador. Esconder o
// <img> revela o quadro de apoio que já está atrás dele, no mesmo
// enquadramento, então o estado de erro não move nada de lugar.
export default class extends Controller {
  static targets = ["image", "fallback"]
  static classes = ["hidden"]

  // Imagem em cache termina de carregar antes de o controller conectar, e o
  // evento `error` já passou quando o data-action entra em vigor. `complete`
  // com largura natural zero é a assinatura dessa falha perdida.
  connect() {
    if (!this.hasImageTarget) return
    if (this.imageTarget.complete && this.imageTarget.naturalWidth === 0) this.failed()
  }

  failed() {
    this.imageTarget.classList.add(...this.hiddenClasses)
    this.fallbackTarget.removeAttribute("aria-hidden")
  }
}
