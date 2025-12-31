# frozen_string_literal: true

# Event published when a post is created
class PostCreatedEvent < ApplicationEvent
  include SmartDomain::Event::ActorMixin

  attribute :post_id, :string

  validates :post_id, presence: true

  # Add domain-specific attributes here
  # Example:
  # attribute :email, :string
  # attribute :name, :string
end
