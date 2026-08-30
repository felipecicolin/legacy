# frozen_string_literal: true

class ErrorsController < ApplicationController
  allow_unauthenticated_access

  def not_found
    authorize_public_page
    render_not_found
  end

  def forbidden
    authorize_public_page
    render_error(:forbidden, :forbidden)
  end

  def unprocessable_entity
    authorize_public_page
    render_unprocessable_entity
  end

  def internal_server_error
    authorize_public_page
    render_error(:internal_server_error, :internal_server_error)
  end
end
