# frozen_string_literal: true

class AppShellComponent < ApplicationComponent
  ACTIONS = "keydown->app-shell#trapFocus keydown.esc->app-shell#close"

  renders_one :navigation
  renders_one :footer

  def stimulus_controller
    "app-shell"
  end

  def html_attributes
    html_options.merge(class: computed_classes, data: controller_data)
  end

  def computed_classes
    class_merge("min-h-screen overflow-x-hidden bg-background text-foreground", html_options[:class])
  end

  def controller_data
    html_options.fetch(:data, {}).to_h.merge(
      controller: stimulus_controller,
      action: ACTIONS,
      "#{stimulus_controller}-open-class": "translate-x-0",
    )
  end
end
