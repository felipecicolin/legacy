// Forbid Tailwind arbitrary values: bg-[#fff], h-[200px], text-[14px], etc.
// Force every value to come from @theme tokens in app/assets/tailwind/tokens.css.
import {
  BaseRuleVisitor,
  ParserRule,
  getAttributes,
  getAttributeName,
  getStaticAttributeValueContent,
} from "@herb-tools/linter"

const PREFIXES = [
  "bg", "text", "border", "from", "to", "via", "fill", "stroke",
  "p", "m", "w", "h", "min-w", "min-h", "max-w", "max-h",
  "gap", "space", "top", "left", "right", "bottom", "inset",
  "rounded", "rotate", "scale", "translate",
  "leading", "tracking", "z", "grid-cols", "grid-rows",
]
const PATTERN = new RegExp(`(?:^|\\s)(?:${PREFIXES.join("|")})-\\[`)

class NoArbitraryTailwindVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    for (const attribute of getAttributes(node)) {
      if (getAttributeName(attribute) !== "class") continue
      const value = getStaticAttributeValueContent(attribute)
      if (!value || !PATTERN.test(value)) continue

      this.addOffense(
        "Arbitrary Tailwind values (bg-[#fff], h-[200px], …) are forbidden. " +
          "Use semantic tokens from app/assets/tailwind/tokens.css.",
        attribute.location,
      )
    }
    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoArbitraryTailwindRule extends ParserRule {
  static ruleName = "no-arbitrary-tailwind"

  check(result, context) {
    const visitor = new NoArbitraryTailwindVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
