# frozen_string_literal: true

class MissionBasePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.visible_to(context.visibility)
  end

  def index?
    true
  end

  def show?
    visible_record?
  end
end
