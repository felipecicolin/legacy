// Forbid hardcoded user-facing text in templates. Every visible string
// must come from `t("...")` so translations are reachable.
//
// Heuristic: flag any HTMLTextNode whose trimmed content contains a
// run of 2+ ASCII letters with at least one lowercase letter (catches
// "Submit", "Save changes", "Welcome back"; ignores "&", "X", "1", "→",
// pure punctuation, numbers).
//
// Templates of `<script>` and `<style>` are not flagged: they're not
// user-facing copy, and their text is rarely human language.
import {
  BaseRuleVisitor,
  ParserRule,
} from "@herb-tools/linter"

const LOOKS_LIKE_COPY = /[A-Za-z]{2,}/
const HAS_LOWERCASE = /[a-z]/

class NoHardcodedStringVisitor extends BaseRuleVisitor {
  constructor(ruleName, context) {
    super(ruleName, context)
    this.skipDepth = 0
  }

  visitHTMLOpenTagNode(node) {
    const tagName = node.tag_name?.value
    if (tagName === "script" || tagName === "style") {
      this.skipDepth++
    }
    super.visitHTMLOpenTagNode(node)
  }

  visitHTMLCloseTagNode(node) {
    const tagName = node.tag_name?.value
    if (tagName === "script" || tagName === "style") {
      this.skipDepth = Math.max(0, this.skipDepth - 1)
    }
    super.visitHTMLCloseTagNode(node)
  }

  visitHTMLTextNode(node) {
    if (this.skipDepth > 0) return super.visitHTMLTextNode(node)

    // Strip HTML entities (&nbsp;, &amp;, &mdash;) so they don't look
    // like English words to the regex.
    const content = (node.content ?? "").replace(/&[a-zA-Z][a-zA-Z0-9]+;|&#\d+;/g, "").trim()
    if (!content) return super.visitHTMLTextNode(node)
    if (!LOOKS_LIKE_COPY.test(content)) return super.visitHTMLTextNode(node)
    if (!HAS_LOWERCASE.test(content)) return super.visitHTMLTextNode(node)

    this.addOffense(
      `Hardcoded user-facing string ${JSON.stringify(content.slice(0, 60))}. ` +
        'Use `t("...")` instead.',
      node.location,
    )

    super.visitHTMLTextNode(node)
  }
}

export default class NoHardcodedStringRule extends ParserRule {
  static ruleName = "no-hardcoded-string"

  check(result, context) {
    const visitor = new NoHardcodedStringVisitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
