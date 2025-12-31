# frozen_string_literal: true

# Base class for all domain services in this application
#
# Inherit from this class to create domain-specific services
#
# Example:
#   class UserService < ApplicationService
#     def create_user(attributes)
#       User.transaction do
#         user = User.create!(attributes)
#         event = build_event(UserCreatedEvent, ...)
#         publish_after_commit(event)
#         user
#       end
#     end
#   end
class ApplicationService < SmartDomain::Domain::Service
  # Add application-wide service methods here
  # Example:
  # def current_organization
  #   @current_organization ||= Organization.find(current_organization_id)
  # end
end
