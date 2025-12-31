# frozen_string_literal: true

# Event published when a user is deleted
class UserDeletedEvent < ApplicationEvent
  include SmartDomain::Event::ActorMixin

  attribute :user_id, :string

  validates :user_id, presence: true

  # Add domain-specific attributes here if needed
  # These should be attributes you want to preserve after deletion
end
