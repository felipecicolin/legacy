# frozen_string_literal: true

class ProjectsController < ApplicationController
  allow_unauthenticated_access only: :show

  def index
    authorize_page
    render_placeholder
  end

  def show
    project = policy_scope(Project).find_by!(code: params.expect(:code))
    authorize project

    render :show, locals: { presenter: ProjectDetailPresenter.new(project, pundit_user,
                                                                  reports_page: params[:reports_page]) }
  end
end
