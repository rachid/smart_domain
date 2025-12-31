# frozen_string_literal: true

# Base class for all domain events in this application
#
# Inherit from this class to create domain-specific events
#
# Example:
#   class UserCreatedEvent < ApplicationEvent
#     attribute :user_id, :string
#     attribute :email, :string
#     validates :user_id, :email, presence: true
#   end
class ApplicationEvent < SmartDomain::Event::Base
  # Add application-wide event fields here
  # Example:
  # attribute :tenant_id, :string
  # validates :tenant_id, presence: true
end
