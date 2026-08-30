import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

// Um gráfico por elemento. A configuração inteira vem do servidor num value:
// a view sabe o que está desenhando, e o controller só monta e destrói.
export default class extends Controller {
  static values = { options: Object }

  connect() {
    this.chart = new ApexCharts(this.element, { ...this.optionsValue, colors: this.palette })
    this.chart.render()
  }

  // O Turbo troca o DOM sem recarregar a página: sem destruir aqui, cada
  // visita deixa um gráfico preso ao elemento antigo.
  disconnect() {
    this.chart?.destroy()
  }

  // As cores saem dos tokens, resolvidas em tempo de execução. Passar hex da
  // view faria o gráfico ser a única coisa da tela que não acompanha uma troca
  // de identidade visual.
  get palette() {
    return ["--color-primary", "--color-accent", "--color-warning", "--color-category-4"]
      .map((name) => this.token(name))
  }

  token(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  }
}
