# frozen_string_literal: true

class SelectComponentPreview < ViewComponent::Preview
  STATUSES = [["Levantamento", "surveying"], ["Em obra", "in_progress"], ["Parada", "paused"]].freeze

  def default
    render(SelectComponent.new(name: :status, label: "Situação", choices: STATUSES,
                               include_blank: "Qualquer uma"))
  end

  def with_a_choice_already_made
    render(SelectComponent.new(name: :status, label: "Situação", choices: STATUSES,
                               selected: "in_progress", include_blank: "Qualquer uma"))
  end

  def without_a_blank_option
    render(SelectComponent.new(name: :status, label: "Situação", choices: STATUSES))
  end
end
