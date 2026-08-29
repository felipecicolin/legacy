# frozen_string_literal: true

class IconComponent < ApplicationComponent
  ICONS_DIR = Rails.root.join("app/assets/images/icons")
  SIZES = {
    xs: "w-3 h-3",
    sm: "w-4 h-4",
    md: "w-5 h-5",
    lg: "w-6 h-6",
    xl: "w-8 h-8",
  }.freeze

  def self.available_names
    ICONS_DIR.glob("*.svg").map { |path| path.basename(".svg").to_s }.sort
  end

  def initialize(name:, size: :md, classes: nil, label: nil)
    super()
    validate_inclusion!(:size, size, SIZES.keys)
    @name = name.to_s
    @size = size
    @classes = classes
    @label = label
    raise ArgumentError, "icon #{@name.inspect} not found in #{ICONS_DIR}" unless icon_path.exist?
  end

  # Um ícone sem rótulo é decorativo e sai do fluxo de leitores de tela; um
  # ícone com rótulo é conteúdo e ganha `title`. Nunca os dois.
  def render_options
    base = { class: class_merge("inline-flex shrink-0", SIZES.fetch(@size), @classes) }
    @label.present? ? base.merge(title: @label, aria: true) : base.merge(aria_hidden: "true")
  end

  attr_reader :name

  private

  def icon_path
    @icon_path ||= ICONS_DIR.join("#{@name}.svg")
  end
end
