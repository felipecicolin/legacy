import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "overlay", "toggle"]
  static classes = ["open"]
  static focusableSelector = "a, button, input, select, textarea, [tabindex]:not([tabindex='-1'])"

  toggle(event) {
    event.preventDefault()
    const opening = !this.isOpen()
    this.setOpenState(opening)
    this.toggleTarget.setAttribute("aria-expanded", String(opening))
    if (opening) this.firstFocusable()?.focus()
  }

  close() {
    if (!this.isOpen()) return
    this.setOpenState(false)
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.toggleTarget.focus()
  }

  trapFocus(event) {
    if (!this.isOpen() || event.key !== "Tab") return
    const items = this.focusableElements()
    if (items.length === 0) return
    this.cycleFocus(event, items)
  }

  isOpen() {
    return this.hasOpenClass && this.drawerTarget.classList.contains(this.openClass)
  }

  setOpenState(open) {
    this.drawerTarget.classList.toggle(this.openClass, open)
    this.overlayTarget.classList.toggle(this.openClass, open)
    this.drawerTarget.setAttribute("aria-hidden", String(!open))
    this.overlayTarget.setAttribute("aria-hidden", String(!open))
  }

  firstFocusable() {
    return this.focusableElements()[0]
  }

  focusableElements() {
    return Array.from(this.drawerTarget.querySelectorAll(this.constructor.focusableSelector))
      .filter((element) => !element.disabled)
  }

  cycleFocus(event, items) {
    const first = items[0]
    const last = items.at(-1)
    if (!this.shouldWrap(event, first, last)) return
    event.preventDefault()
    this.wrapFocus(event, first, last)
  }

  shouldWrap(event, first, last) {
    return this.atFirst(event, first) || this.atLast(event, last)
  }

  atFirst(event, first) {
    return event.shiftKey && document.activeElement === first
  }

  atLast(event, last) {
    return !event.shiftKey && document.activeElement === last
  }

  wrapFocus(event, first, last) {
    const target = event.shiftKey ? last : first
    target.focus()
  }
}
