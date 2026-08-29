// Forbid `data-turbo="false"` escape hatch. Turbo is mandatory; if a behavior
// fights Turbo, fix the root cause (Turbo Frame, Turbo Stream, or Stimulus
// controller) — never disable Turbo.
import {
  BaseRuleVisitor,
  ParserRule,
  getAttributes,
  getAttributeName,
  getStaticAttributeValueContent,
} from "@herb-tools/linter"

class NoTurboDisableVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    for (const attribute of getAttributes(node)) {
      const name = getAttributeName(attribute)
      if (name !== "data-turbo") continue
      const value = getStaticAttributeValueContent(attribute)
      if (value !== "false") continue

      this.addOffense(
        'data-turbo="false" is forbidden. Use a Turbo Frame, Turbo Stream, ' +
          "or a Stimulus controller — never disable Turbo.",
        attribute.location,
      )
    }
    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoTurboDisableRule extends ParserRule {
  static ruleName = "no-turbo-disable"

  check(result, context) {
    const visitor = new NoTurboDisableVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
