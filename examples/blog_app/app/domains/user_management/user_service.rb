# frozen_string_literal: true

module UserManagement
  # Service for User business logic
  #
  # This service encapsulates all business operations for users.
  # Controllers should delegate to this service rather than directly
  # manipulating User models.
  class UserService < ApplicationService
    # Create a new user
    #
    # @param attributes [Hash] User attributes
    # @return [User] Created user
    # @raise [SmartDomain::Domain::AlreadyExistsError] If user already exists
    # @raise [SmartDomain::Domain::ValidationError] If validation fails
    def create_user(attributes)
      # Example business rule validation
      # if User.exists?(email: attributes[:email])
      #   raise SmartDomain::Domain::AlreadyExistsError.new('User', 'email', attributes[:email])
      # end

      User.transaction do
        user = User.create!(attributes)

        # Event is published via ActiveRecord integration
        # Or manually:
        # event = build_event(UserCreatedEvent,
        #   event_type: 'user.created',
        #   aggregate_id: user.id,
        #   aggregate_type: 'User',
        #   user_id: user.id
        # )
        # publish_after_commit(event)

        log(:info, "User created", user_id: user.id)
        user
      end
    end

    # Update an existing user
    #
    # @param user [User, Integer, String] User object or ID
    # @param attributes [Hash] Attributes to update
    # @return [User] Updated user
    # @raise [ActiveRecord::RecordNotFound] If user not found
    # @raise [SmartDomain::Domain::UnauthorizedError] If not authorized
    def update_user(user, attributes)
      user = User.find(user) unless user.is_a?(User)

      # Authorization check
      policy = UserPolicy.new(current_user, user)
      authorize!(policy, :update?)

      User.transaction do
        user.update!(attributes)

        # Event published via ActiveRecord integration
        log(:info, "User updated", user_id: user.id, changes: user.saved_changes.keys)
        user
      end
    end

    # Delete a user
    #
    # @param user [User, Integer, String] User object or ID
    # @return [Boolean] True if deleted
    # @raise [ActiveRecord::RecordNotFound] If user not found
    # @raise [SmartDomain::Domain::UnauthorizedError] If not authorized
    def delete_user(user)
      user = User.find(user) unless user.is_a?(User)

      # Authorization check
      policy = UserPolicy.new(current_user, user)
      authorize!(policy, :destroy?)

      User.transaction do
        user.destroy!

        # Event published via ActiveRecord integration
        log(:info, "User deleted", user_id: user.id)
        true
      end
    end

    # List users with policy scope
    #
    # @param scope [ActiveRecord::Relation] Optional base scope
    # @return [ActiveRecord::Relation] Scoped users
    def list_users(scope = User.all)
      policy_scope(scope, UserPolicy)
    end
  end
end
