// Forbid raw <button> and <input type="submit|button|reset"> outside the
// design system. Use ButtonComponent (or another component) instead.
//
// Path scoping is configured in .herb.yml — this rule excludes
// app/components/** there. We don't filter inside the rule itself.
import {
  BaseRuleVisitor,
  ParserRule,
  getAttributes,
  getAttributeName,
  getStaticAttributeValueContent,
} from "@herb-tools/linter"

const FORBIDDEN_INPUT_TYPES = new Set(["submit", "button", "reset"])

class NoRawButtonVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    if (!node.tag_name) return

    const tagName = node.tag_name.value

    if (tagName === "button") {
      this.addOffense(
        "Raw <button> is forbidden. Use ButtonComponent (or another design-system component).",
        node.tag_name.location,
      )
      super.visitHTMLOpenTagNode(node)
      return
    }

    if (tagName === "input") {
      const typeAttr = getAttributes(node).find(
        (attr) => getAttributeName(attr) === "type",
      )
      const typeValue = typeAttr ? getStaticAttributeValueContent(typeAttr) : null

      if (typeValue && FORBIDDEN_INPUT_TYPES.has(typeValue)) {
        this.addOffense(
          `Raw <input type="${typeValue}"> is forbidden. Use ButtonComponent instead.`,
          node.tag_name.location,
        )
      }
    }

    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoRawButtonRule extends ParserRule {
  static ruleName = "no-raw-button"

  check(result, context) {
    const visitor = new NoRawButtonVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
