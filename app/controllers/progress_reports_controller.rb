# frozen_string_literal: true

class ProgressReportsController < ApplicationController
  def index
    authorize_page
    render_placeholder
  end

  def show
    authorize_page
    render_placeholder
  end

  def create
    authorize_page
    params.expect(progress_report: %i[body])
    render_placeholder
  end
end
