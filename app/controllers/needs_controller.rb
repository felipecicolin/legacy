# frozen_string_literal: true

class NeedsController < ApplicationController
  def index
    authorize_page
    render_placeholder
  end

  def show
    authorize_page
    render_placeholder
  end
end
