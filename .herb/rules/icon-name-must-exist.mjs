// Validate that every `IconComponent.new(name: "...")` call references a
// real SVG file in app/assets/icons/. Prevents the most common UI
// hallucination — AI inventing icon names ("trash", "settings", "user")
// that the catalog doesn't ship.
//
// Catalog is read once per process from app/assets/images/icons/*.svg at
// the time the rule first runs — the same directory IconComponent::ICONS_DIR
// reads, so the linter and the runtime can never disagree. Only string and
// symbol literal names are checked; dynamic names (variables,
// interpolations) are skipped.
import { readdirSync, existsSync } from "node:fs"
import { join } from "node:path"

import {
  BaseSourceRuleVisitor,
  SourceRule,
  locationFromContentOffset,
} from "@herb-tools/linter"
import { Location } from "@herb-tools/core"

const ICONS_DIR = "app/assets/images/icons"
// Duas formas, e a segunda existe porque a primeira não bastou: o nome do
// ícone também viaja como PROP de outro componente
// (`EmptyStateComponent.new(icon: "user")`), e por esse caminho um nome
// inventado passou pelo linter e só quebrou em runtime, na renderização.
const CALLS = [
  /IconComponent\.new\(\s*name:\s*["':]([\w-]+)["']?/g,
  /\w+Component\.new\([^)]*?\bicon:\s*["':]([\w-]+)["']?/g,
]

let cachedCatalog = null

function loadCatalog() {
  if (cachedCatalog) return cachedCatalog
  const dir = join(process.cwd(), ICONS_DIR)
  if (!existsSync(dir)) {
    cachedCatalog = new Set()
    return cachedCatalog
  }
  const names = readdirSync(dir)
    .filter((f) => f.endsWith(".svg"))
    .map((f) => f.replace(/\.svg$/, ""))
  cachedCatalog = new Set(names)
  return cachedCatalog
}

class IconNameVisitor extends BaseSourceRuleVisitor {
  visitSource(source) {
    const catalog = loadCatalog()
    if (catalog.size === 0) return

    for (const pattern of CALLS) this.checkPattern(source, pattern, catalog)
  }

  checkPattern(source, CALL, catalog) {
    CALL.lastIndex = 0
    let match
    while ((match = CALL.exec(source)) !== null) {
      const name = match[1]
      if (catalog.has(name)) continue

      // Locate the name token within the matched call (skip past `name:`).
      // `locationFromContentOffset` resolves an offset into the file to a
      // line/column pair; the source of a SourceRule starts at line 1,
      // column 0. Two calls because it returns a one-character span — the
      // offense should underline the whole icon name.
      const offset = match.index + match[0].lastIndexOf(name)
      const start = locationFromContentOffset(1, 0, source, offset).start
      const end = locationFromContentOffset(1, 0, source, offset + name.length).start
      const location = new Location(start, end)

      const known = [...catalog].sort().join(", ")
      this.addOffense(
        `Icon "${name}" not found in ${ICONS_DIR}/. Available: ${known}.`,
        location,
      )
    }
  }
}

export default class IconNameMustExistRule extends SourceRule {
  static ruleName = "icon-name-must-exist"

  check(source, context) {
    const visitor = new IconNameVisitor(this.ruleName, context)
    visitor.visitSource(source)
    return visitor.offenses
  }
}
