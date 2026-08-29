// Forbid inline <svg> in any ERB template — icons must go through
// IconComponent so they honour the catalog + currentColor + size tokens.
import {
  BaseRuleVisitor,
  ParserRule,
} from "@herb-tools/linter"

class NoInlineSvgVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    if (node.tag_name && node.tag_name.value === "svg") {
      this.addOffense(
        "Inline <svg> is forbidden. Drop the SVG into app/assets/icons/<name>.svg " +
          "and render it via IconComponent.new(name: \"<name>\").",
        node.tag_name.location,
      )
    }
    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoInlineSvgRule extends ParserRule {
  static ruleName = "no-inline-svg"

  check(result, context) {
    const visitor = new NoInlineSvgVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
