// Forbid hex color codes (#fff, #FFFFFF, #ffaabb88) and rgb()/rgba()/hsl()
// literals in any template attribute. All colors must come from semantic
// tokens defined in app/assets/tailwind/tokens.css.
import {
  BaseRuleVisitor,
  ParserRule,
  getAttributes,
  getStaticAttributeValueContent,
} from "@herb-tools/linter"

const HEX_OR_FUNCTION = /(?:#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b|\brgba?\(|\bhsla?\()/

class NoHexCodeVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    for (const attribute of getAttributes(node)) {
      const value = getStaticAttributeValueContent(attribute)
      if (!value || !HEX_OR_FUNCTION.test(value)) continue

      this.addOffense(
        "Hex codes and rgb()/hsl() literals are forbidden. " +
          "Use semantic tokens (bg-primary, text-foreground, …).",
        attribute.location,
      )
    }
    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoHexCodeRule extends ParserRule {
  static ruleName = "no-hex-code"

  check(result, context) {
    const visitor = new NoHexCodeVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
