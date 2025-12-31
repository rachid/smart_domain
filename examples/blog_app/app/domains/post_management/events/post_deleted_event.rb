# frozen_string_literal: true

# Event published when a post is deleted
class PostDeletedEvent < ApplicationEvent
  include SmartDomain::Event::ActorMixin

  attribute :post_id, :string

  validates :post_id, presence: true

  # Add domain-specific attributes here if needed
  # These should be attributes you want to preserve after deletion
end
