# frozen_string_literal: true

# Event published when a post is updated
class PostUpdatedEvent < ApplicationEvent
  include SmartDomain::Event::ActorMixin
  include SmartDomain::Event::ChangeTrackingMixin

  attribute :post_id, :string

  validates :post_id, presence: true

  # Add domain-specific attributes here if needed
end
