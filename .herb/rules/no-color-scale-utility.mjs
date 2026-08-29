// Forbid Tailwind primitive color-scale utilities: bg-blue-500, text-gray-700,
// border-red-300, etc. Force every consumer to use semantic tokens
// (bg-primary, text-muted-foreground, border-destructive). The primitive
// scale stays available *inside* @theme as the implementation backing
// semantic aliases, but never directly in templates.
import {
  BaseRuleVisitor,
  ParserRule,
  getAttributes,
  getAttributeName,
  getStaticAttributeValueContent,
} from "@herb-tools/linter"

const COLORS = [
  "slate", "gray", "zinc", "neutral", "stone",
  "red", "orange", "amber", "yellow", "lime", "green", "emerald", "teal",
  "cyan", "sky", "blue", "indigo",
  "violet", "purple", "fuchsia", "pink", "rose",
]
const PREFIXES = [
  "bg", "text", "border", "from", "to", "via", "fill", "stroke",
  "ring", "outline", "divide", "placeholder", "caret", "accent",
  "decoration", "shadow",
]
const PATTERN = new RegExp(
  `(?:^|\\s)(?:${PREFIXES.join("|")})-(?:${COLORS.join("|")})-\\d{2,3}\\b`,
)

class NoColorScaleUtilityVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    for (const attribute of getAttributes(node)) {
      if (getAttributeName(attribute) !== "class") continue
      const value = getStaticAttributeValueContent(attribute)
      if (!value || !PATTERN.test(value)) continue

      this.addOffense(
        "Tailwind color-scale utilities (bg-blue-500, text-gray-700, …) are forbidden. " +
          "Use semantic tokens (bg-primary, text-muted-foreground, …).",
        attribute.location,
      )
    }
    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoColorScaleUtilityRule extends ParserRule {
  static ruleName = "no-color-scale-utility"

  check(result, context) {
    const visitor = new NoColorScaleUtilityVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
