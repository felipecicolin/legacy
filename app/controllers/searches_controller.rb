# frozen_string_literal: true

class SearchesController < ApplicationController
  def show
    authorize_page
    params.expect(:query)
    render_placeholder
  end
end
