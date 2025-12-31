# frozen_string_literal: true

# Event published when a user is updated
class UserUpdatedEvent < ApplicationEvent
  include SmartDomain::Event::ActorMixin
  include SmartDomain::Event::ChangeTrackingMixin

  attribute :user_id, :string

  validates :user_id, presence: true

  # Add domain-specific attributes here if needed
end
