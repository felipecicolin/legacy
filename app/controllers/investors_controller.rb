# frozen_string_literal: true

# A visão do investidor: quanto aportou, em que obras isso entrou, quantas
# pessoas a fatia dele alcança por ano e o multiplicador que resume as duas
# coisas. Ver docs/investor-dashboard.md.
class InvestorsController < ApplicationController
  def show
    authorize_page
    profile = Current.user.profile
    return render :no_profile if profile.blank?

    render :show, locals: { dashboard: InvestorDashboard.new(profile, pundit_user) }
  end
end
