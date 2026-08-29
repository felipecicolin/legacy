// Forbid inline DOM event handlers (onclick=, onchange=, onsubmit=, …).
// All client behavior must go through Stimulus controllers via data-action.
import {
  BaseRuleVisitor,
  ParserRule,
  getAttributes,
  getAttributeName,
} from "@herb-tools/linter"

const HANDLER = /^on[a-z]+$/

class NoInlineEventHandlerVisitor extends BaseRuleVisitor {
  visitHTMLOpenTagNode(node) {
    for (const attribute of getAttributes(node)) {
      const name = getAttributeName(attribute)
      if (!name || !HANDLER.test(name)) continue

      this.addOffense(
        `Inline event handler "${name}" is forbidden. ` +
          "Use a Stimulus controller with data-action.",
        attribute.location,
      )
    }
    super.visitHTMLOpenTagNode(node)
  }
}

export default class NoInlineEventHandlerRule extends ParserRule {
  static ruleName = "no-inline-event-handler"

  check(result, context) {
    const visitor = new NoInlineEventHandlerVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
