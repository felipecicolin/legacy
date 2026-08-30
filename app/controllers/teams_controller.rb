# frozen_string_literal: true

# A visão do time da obra. Ver docs/team-dashboard.md.
class TeamsController < ApplicationController
  def show
    authorize_page
    profile = Current.user.profile
    return render :no_profile if profile.blank?

    render :show, locals: { dashboard: TeamDashboard.new(profile, pundit_user) }
  end
end
