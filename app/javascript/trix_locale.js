// Rótulos da barra de ferramentas do Trix em pt-BR.
//
// Por que não passa pelo `t()` do Rails: a barra é construída em JavaScript,
// pelo próprio Trix, a partir de `Trix.config.lang`. Nada dela chega ao ERB, e
// nenhum dos três linters de i18n do repositório enxerga estes textos.
//
// Por que é `Object.assign` e não `Trix.config.lang = {...}`: o gerador do HTML
// padrão da barra fecha sobre o OBJETO de lang, não sobre `config.lang`.
// Substituir o objeto deixaria o gerador lendo o antigo, em inglês, sem erro
// nenhum.
//
// Por que a chamada é explícita, de dentro do `application.js`, e não um efeito
// colateral no topo deste arquivo: é a regra `no_top_level_side_effects` do
// `bin/stimulus_lint`, e a ordem também depende disso — `Trix.config.lang`
// precisa estar traduzido ANTES de o custom element `trix-editor` ser definido.
// O Trix registra `customElements.define` dentro de um `setTimeout`, então
// qualquer código síncrono do `application.js` chega primeiro; um `connect()`
// de Stimulus, que espera o DOM, chegaria tarde demais e a barra sairia em
// inglês — sem falhar em lugar nenhum.
import Trix from "trix"

const PT_BR = {
  attachFiles: "Anexar arquivos",
  bold: "Negrito",
  bullets: "Lista com marcadores",
  byte: "Byte",
  bytes: "Bytes",
  captionPlaceholder: "Adicione uma legenda…",
  code: "Código",
  heading1: "Título",
  indent: "Aumentar nível",
  italic: "Itálico",
  link: "Link",
  numbers: "Lista numerada",
  outdent: "Diminuir nível",
  quote: "Citação",
  redo: "Refazer",
  remove: "Remover",
  strike: "Tachado",
  undo: "Desfazer",
  unlink: "Remover link",
  url: "URL",
  urlPlaceholder: "Digite uma URL…",
  GB: "GB",
  KB: "KB",
  MB: "MB",
  PB: "PB",
  TB: "TB",
}

export function localizeTrix() {
  Object.assign(Trix.config.lang, PT_BR)
}
