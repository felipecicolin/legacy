# frozen_string_literal: true

class NeedPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.visible_to(context.visibility)
  end

  def index? = true

  def show? = visible_record?

  # Candidatar-se exige ver a necessidade — e a recusa por não ver sai pela
  # mesma porta da recusa por não existir. Ver docs/authorization.md.
  def create? = context.signed_in? && visible_record?

  def new? = create?
end
