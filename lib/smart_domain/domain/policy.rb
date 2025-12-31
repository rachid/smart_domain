# frozen_string_literal: true

module SmartDomain
  module Domain
    # Base class for domain policies (authorization).
    #
    # Policies encapsulate authorization logic for domain operations.
    # They follow the Pundit-style pattern but are domain-centric.
    #
    # Key principles:
    # - Policies are stateless (except for user and record context)
    # - Policies answer "can this user perform this action on this record?"
    # - Policies can be used in services, controllers, and views
    # - Policies are domain-specific (UserPolicy, OrderPolicy, etc.)
    #
    # @example Define a policy
    #   class UserPolicy < SmartDomain::Domain::Policy
    #     def create?
    #       user.admin? || user.manager?
    #     end
    #
    #     def update?
    #       user.admin? || user.id == record.id
    #     end
    #
    #     def delete?
    #       user.admin? && record.id != user.id
    #     end
    #
    #     def activate?
    #       user.admin? && record.pending?
    #     end
    #   end
    #
    # @example Use in a service
    #   class UserService < SmartDomain::Domain::Service
    #     def activate_user(user_id)
    #       user = User.find(user_id)
    #       policy = UserPolicy.new(current_user, user)
    #
    #       authorize!(policy, :activate?)
    #
    #       user.update!(status: 'active')
    #       # ... publish event ...
    #     end
    #   end
    class Policy
      attr_reader :user, :record

      # Initialize policy
      #
      # @param user [Object] User performing the action (current_user)
      # @param record [Object] Record being operated on
      def initialize(user, record)
        @user = user
        @record = record
      end

      # Check if user can perform index action
      # Override in subclass
      # @return [Boolean]
      def index?
        false
      end

      # Check if user can perform show action
      # Override in subclass
      # @return [Boolean]
      def show?
        false
      end

      # Check if user can perform create action
      # Override in subclass
      # @return [Boolean]
      def create?
        false
      end

      # Check if user can perform update action
      # Override in subclass
      # @return [Boolean]
      def update?
        false
      end

      # Check if user can perform destroy action
      # Override in subclass
      # @return [Boolean]
      def destroy?
        false
      end

      # Scope for index queries
      #
      # Override in subclass to return a scope of records
      # the user can access.
      #
      # @param scope [ActiveRecord::Relation] Initial scope
      # @return [ActiveRecord::Relation] Filtered scope
      #
      # @example
      #   class UserPolicy < SmartDomain::Domain::Policy
      #     class Scope
      #       attr_reader :user, :scope
      #
      #       def initialize(user, scope)
      #         @user = user
      #         @scope = scope
      #       end
      #
      #       def resolve
      #         if user.admin?
      #           scope.all
      #         else
      #           scope.where(organization_id: user.organization_id)
      #         end
      #       end
      #     end
      #   end
      class Scope
        attr_reader :user, :scope

        def initialize(user, scope)
          @user = user
          @scope = scope
        end

        # Resolve scope based on user permissions
        # Override in subclass
        # @return [ActiveRecord::Relation]
        def resolve
          scope.none
        end
      end

      # Helper method to check if user is present
      # @return [Boolean]
      def user_present?
        !user.nil?
      end

      # Helper method to check if user is admin
      # Override in subclass based on your user model
      # @return [Boolean]
      def admin?
        user_present? && user.respond_to?(:admin?) && user.admin?
      end

      # Helper method to check if user owns the record
      # @return [Boolean]
      def owner?
        user_present? && record.respond_to?(:user_id) && record.user_id == user.id
      end

      # Helper method to check if user is in same organization
      # @return [Boolean]
      def same_organization?
        user_present? &&
          record.respond_to?(:organization_id) &&
          user.respond_to?(:organization_id) &&
          record.organization_id == user.organization_id
      end
    end

    # Authorization helper methods for services
    module PolicyHelpers
      # Authorize an action or raise an error
      #
      # @param policy [SmartDomain::Domain::Policy] Policy instance
      # @param action [Symbol] Action to authorize (e.g., :create?, :update?)
      # @raise [SmartDomain::Domain::UnauthorizedError] If not authorized
      #
      # @example
      #   policy = UserPolicy.new(current_user, user)
      #   authorize!(policy, :update?)
      def authorize!(policy, action)
        return if policy.public_send(action)

        raise SmartDomain::Domain::UnauthorizedError.new(
          "Not authorized to perform #{action} on #{policy.record.class.name}",
          action: action,
          resource: policy.record.class.name
        )
      end

      # Check if action is authorized
      #
      # @param policy [SmartDomain::Domain::Policy] Policy instance
      # @param action [Symbol] Action to check
      # @return [Boolean] True if authorized
      #
      # @example
      #   policy = UserPolicy.new(current_user, user)
      #   if authorized?(policy, :update?)
      #     # perform update
      #   end
      def authorized?(policy, action)
        policy.public_send(action)
      end

      # Get scoped records based on user permissions
      #
      # @param scope [ActiveRecord::Relation] Initial scope
      # @param policy_class [Class] Policy class
      # @return [ActiveRecord::Relation] Filtered scope
      #
      # @example
      #   users = policy_scope(User.all, UserPolicy)
      def policy_scope(scope, policy_class)
        policy_class::Scope.new(current_user, scope).resolve
      end
    end
  end
end
