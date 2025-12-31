# frozen_string_literal: true

module PostManagement
  # Service for Post business logic
  #
  # This service encapsulates all business operations for posts.
  # Controllers should delegate to this service rather than directly
  # manipulating Post models.
  class PostService < ApplicationService
    # Create a new post
    #
    # @param attributes [Hash] Post attributes
    # @return [Post] Created post
    # @raise [SmartDomain::Domain::AlreadyExistsError] If post already exists
    # @raise [SmartDomain::Domain::ValidationError] If validation fails
    def create_post(attributes)
      # Example business rule validation
      # if Post.exists?(email: attributes[:email])
      #   raise SmartDomain::Domain::AlreadyExistsError.new('Post', 'email', attributes[:email])
      # end

      Post.transaction do
        post = Post.create!(attributes)

        # Event is published via ActiveRecord integration
        # Or manually:
        # event = build_event(PostCreatedEvent,
        #   event_type: 'post.created',
        #   aggregate_id: post.id,
        #   aggregate_type: 'Post',
        #   post_id: post.id
        # )
        # publish_after_commit(event)

        log(:info, "Post created", post_id: post.id)
        post
      end
    end

    # Update an existing post
    #
    # @param post [Post, Integer, String] Post object or ID
    # @param attributes [Hash] Attributes to update
    # @return [Post] Updated post
    # @raise [ActiveRecord::RecordNotFound] If post not found
    # @raise [SmartDomain::Domain::UnauthorizedError] If not authorized
    def update_post(post, attributes)
      post = Post.find(post) unless post.is_a?(Post)

      # Authorization check
      policy = PostPolicy.new(current_user, post)
      authorize!(policy, :update?)

      Post.transaction do
        post.update!(attributes)

        # Event published via ActiveRecord integration
        log(:info, "Post updated", post_id: post.id, changes: post.saved_changes.keys)
        post
      end
    end

    # Delete a post
    #
    # @param post [Post, Integer, String] Post object or ID
    # @return [Boolean] True if deleted
    # @raise [ActiveRecord::RecordNotFound] If post not found
    # @raise [SmartDomain::Domain::UnauthorizedError] If not authorized
    def delete_post(post)
      post = Post.find(post) unless post.is_a?(Post)

      # Authorization check
      policy = PostPolicy.new(current_user, post)
      authorize!(policy, :destroy?)

      Post.transaction do
        post.destroy!

        # Event published via ActiveRecord integration
        log(:info, "Post deleted", post_id: post.id)
        true
      end
    end

    # List posts with policy scope
    #
    # @param scope [ActiveRecord::Relation] Optional base scope
    # @return [ActiveRecord::Relation] Scoped posts
    def list_posts(scope = Post.all)
      policy_scope(scope, PostPolicy)
    end
  end
end
