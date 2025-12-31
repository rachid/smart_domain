# frozen_string_literal: true

# Event published when a user is created
class UserCreatedEvent < ApplicationEvent
  include SmartDomain::Event::ActorMixin

  attribute :user_id, :string

  validates :user_id, presence: true

  # Add domain-specific attributes here
  # Example:
  # attribute :email, :string
  # attribute :name, :string
end
