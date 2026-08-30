# frozen_string_literal: true

class CampaignsController < ApplicationController
  def index
    authorize_page
    render_placeholder
  end

  def show
    authorize_page
    render_placeholder
  end
end
