# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authorize_staff_page
  end
end
