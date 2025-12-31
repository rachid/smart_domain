# frozen_string_literal: true

# Authorization policy for User
#
# Define authorization rules for user operations.
# These methods are called from services and controllers.
class UserPolicy < ApplicationPolicy
  # Can user view list of users?
  def index?
    user_present?
  end

  # Can user view this user?
  def show?
    user_present? && (admin? || same_organization?)
  end

  # Can user create a user?
  def create?
    user_present?
  end

  # Can user update this user?
  def update?
    user_present? && (admin? || owner? || same_organization?)
  end

  # Can user delete this user?
  def destroy?
    user_present? && (admin? || owner?)
  end

  # Scope for index queries
  #
  # Returns only users the user is authorized to see
  class Scope < Scope
    def resolve
      if user.nil?
        scope.none
      elsif user.respond_to?(:admin?) && user.admin?
        scope.all
      elsif user.respond_to?(:organization_id)
        scope.where(organization_id: user.organization_id)
      else
        scope.where(user_id: user.id)
      end
    end
  end
end
