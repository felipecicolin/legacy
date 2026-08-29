// Validate that every `IconComponent.new(name: "...")` call references a
// real SVG file in app/assets/icons/. Prevents the most common UI
// hallucination — AI inventing icon names ("trash", "settings", "user")
// that the catalog doesn't ship.
//
// Catalog is read once per process from app/assets/icons/*.svg at the
// time the rule first runs. Only string and symbol literal names are
// checked; dynamic names (variables, interpolations) are skipped.
import { readdirSync, existsSync } from "node:fs"
import { join } from "node:path"

import {
  BaseSourceRuleVisitor,
  SourceRule,
  positionFromOffset,
} from "@herb-tools/linter"
import { Location } from "@herb-tools/core"

const ICONS_DIR = "app/assets/icons"
const CALL = /IconComponent\.new\(\s*name:\s*["':]([\w-]+)["']?/g

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

    let match
    while ((match = CALL.exec(source)) !== null) {
      const name = match[1]
      if (catalog.has(name)) continue

      // Locate the name token within the matched call (skip past `name:`).
      const offset = match.index + match[0].lastIndexOf(name)
      const start = positionFromOffset(source, offset)
      const end = positionFromOffset(source, offset + name.length)
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
