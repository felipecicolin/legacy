# frozen_string_literal: true

class NeedsController < ApplicationController
  allow_unauthenticated_access only: :show

  # A visão do voluntário: o que ele pode servir, o que já pediu, e o que falta
  # nele para poder pedir. Ver docs/mobilization.md.
  def index
    authorize_page
    profile = Current.user.profile
    return render :no_profile if profile.blank?

    render :index, locals: { dashboard: dashboard_for(profile), filters: filters }
  end

  def show
    need = policy_scope(Need).find(params.expect(:id))
    authorize need

    render :show, locals: { need: need, candidacy: need.candidacies.new }
  end

  private

  def dashboard_for(profile)
    VolunteerDashboard.new(profile, pundit_user)
  end

  def filters = Search::Filters.from(params)
end
