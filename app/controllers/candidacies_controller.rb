# frozen_string_literal: true

class CandidaciesController < ApplicationController
  def new
    authorize_page
    render_placeholder
  end

  def create
    authorize_page
    params.expect(candidacy: %i[message])
    render_placeholder
  end
end
