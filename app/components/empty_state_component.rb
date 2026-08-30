# frozen_string_literal: true

class EmptyStateComponent < ApplicationComponent
  renders_one :action

  def initialize(icon:, title:, description: nil, **html_options)
    @icon = icon
    @title = title
    @description = description
    super(**html_options)
  end

  def html_attributes
    html_options.merge(class: computed_classes)
  end

  def computed_classes
    class_merge("flex min-h-64 flex-col items-center justify-center rounded-lg border border-border " \
                "bg-card px-6 py-10 text-center", html_options[:class])
  end

  attr_reader :icon, :title, :description
end
