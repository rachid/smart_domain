# frozen_string_literal: true

# Base class for all domain policies in this application
#
# Inherit from this class to create domain-specific policies
#
# Example:
#   class UserPolicy < ApplicationPolicy
#     def update?
#       user.admin? || owner?
#     end
#
#     def destroy?
#       user.admin?
#     end
#   end
class ApplicationPolicy < SmartDomain::Domain::Policy
  # Add application-wide policy methods here
  # Example:
  # def manager?
  #   user.present? && user.role == 'manager'
  # end
end
