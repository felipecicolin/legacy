# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.visible_to(context.visibility)
  end

  def index?
    true
  end

  def show?
    visible_record?
  end

  def progress_report?
    project_participant? || context.platform_admin?
  end

  private

  def project_participant?
    participation = record.try(:project_participations)&.find_by(profile: context.profile)
    participation&.role.in?(%w[owner admin representative])
  end
end
