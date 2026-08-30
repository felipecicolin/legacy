# frozen_string_literal: true

module Admin
  class FundraisingController < BaseController
    def show
      @dashboard = FundraisingDashboard.new(pundit_user)
    end
  end
end
