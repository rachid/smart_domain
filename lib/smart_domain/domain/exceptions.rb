# frozen_string_literal: true

module SmartDomain
  module Domain
    # Base exception for all domain errors
    #
    # Domain exceptions represent business rule violations and should be
    # handled differently from technical errors (like database errors).
    #
    # @example Define domain-specific exceptions
    #   class UserNotFoundError < SmartDomain::Domain::Error
    #     def initialize(user_id)
    #       super("User not found: #{user_id}")
    #     end
    #   end
    #
    #   class UserAlreadyExistsError < SmartDomain::Domain::Error
    #     def initialize(email)
    #       super("User with email #{email} already exists")
    #     end
    #   end
    class Error < StandardError
      attr_reader :code, :details

      # Initialize domain error
      #
      # @param message [String] Error message
      # @param code [Symbol, nil] Error code for programmatic handling
      # @param details [Hash, nil] Additional error details
      def initialize(message, code: nil, details: {})
        super(message)
        @code = code
        @details = details
      end

      # Convert error to hash (useful for API responses)
      #
      # @return [Hash] Error representation
      def to_h
        {
          error: self.class.name,
          message: message,
          code: code,
          details: details
        }.compact
      end

      alias to_hash to_h
    end

    # Error raised when an entity is not found
    #
    # @example
    #   raise SmartDomain::Domain::NotFoundError.new('User', user_id)
    class NotFoundError < Error
      def initialize(entity_type, entity_id)
        super(
          "#{entity_type} not found: #{entity_id}",
          code: :not_found,
          details: { entity_type: entity_type, entity_id: entity_id }
        )
      end
    end

    # Error raised when an entity already exists
    #
    # @example
    #   raise SmartDomain::Domain::AlreadyExistsError.new('User', 'email', email)
    class AlreadyExistsError < Error
      def initialize(entity_type, attribute, value)
        super(
          "#{entity_type} with #{attribute} '#{value}' already exists",
          code: :already_exists,
          details: { entity_type: entity_type, attribute: attribute, value: value }
        )
      end
    end

    # Error raised when a business rule is violated
    #
    # @example
    #   raise SmartDomain::Domain::BusinessRuleError.new(
    #     'Cannot delete user with active orders'
    #   )
    class BusinessRuleError < Error
      def initialize(message, code: :business_rule_violation, details: {})
        super
      end
    end

    # Error raised when an invalid state transition is attempted
    #
    # @example
    #   raise SmartDomain::Domain::InvalidStateError.new(
    #     'User',
    #     from: 'suspended',
    #     to: 'active',
    #     reason: 'User must be pending to activate'
    #   )
    class InvalidStateError < Error
      def initialize(entity_type, from:, to:, reason: nil)
        message = "Invalid state transition for #{entity_type}: #{from} -> #{to}"
        message += " (#{reason})" if reason

        super(
          message,
          code: :invalid_state,
          details: { entity_type: entity_type, from: from, to: to, reason: reason }
        )
      end
    end

    # Error raised when validation fails
    #
    # @example
    #   raise SmartDomain::Domain::ValidationError.new(
    #     'User validation failed',
    #     errors: { email: ['is required'], name: ['is too short'] }
    #   )
    class ValidationError < Error
      def initialize(message, errors: {})
        super(
          message,
          code: :validation_failed,
          details: { validation_errors: errors }
        )
      end
    end

    # Error raised when authorization fails
    #
    # @example
    #   raise SmartDomain::Domain::UnauthorizedError.new(
    #     'User does not have permission to delete this resource'
    #   )
    class UnauthorizedError < Error
      def initialize(message = 'Unauthorized', action: nil, resource: nil)
        super(
          message,
          code: :unauthorized,
          details: { action: action, resource: resource }.compact
        )
      end
    end

    # Error raised when a required dependency is not available
    #
    # @example
    #   raise SmartDomain::Domain::DependencyError.new(
    #     'Redis',
    #     'Redis is required for caching'
    #   )
    class DependencyError < Error
      def initialize(dependency_name, message = nil)
        message ||= "Required dependency not available: #{dependency_name}"
        super(
          message,
          code: :dependency_missing,
          details: { dependency: dependency_name }
        )
      end
    end
  end
end
