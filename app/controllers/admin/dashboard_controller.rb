# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      @dashboard = DashboardPresenter.new(pundit_user.visibility)
    end
  end
end
