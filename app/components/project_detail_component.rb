# frozen_string_literal: true

class ProjectDetailComponent < ApplicationComponent
  def initialize(presenter:)
    super()
    @presenter = presenter
  end

  attr_reader :presenter
end
