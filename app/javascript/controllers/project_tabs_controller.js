import { Controller } from "@hotwired/stimulus"

// Abas de uma tela só. Sem rota por aba de propósito: a obra tem UMA URL, e
// trocar de seção não é navegar para outro recurso — é olhar outro lado do
// mesmo. Ver docs/team-dashboard.md.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.show(0)
  }

  select(event) {
    this.show(this.tabTargets.indexOf(event.currentTarget))
  }

  // `hidden` e não classe: o conteúdo escondido sai da árvore de acessibilidade
  // junto, que é o que um leitor de tela precisa.
  show(index) {
    this.tabTargets.forEach((tab, at) => tab.setAttribute("aria-selected", at === index))
    this.panelTargets.forEach((panel, at) => { panel.hidden = at !== index })
  }
}
