# frozen_string_literal: true

module SmartDomain
  module Domain
    # Base class for domain services.
    #
    # Domain services contain business logic that doesn't naturally fit
    # within a single entity. They orchestrate operations across multiple
    # entities and publish domain events.
    #
    # Key principles:
    # - Services own business logic, not controllers
    # - Services publish events after successful operations
    # - Services use transactions for data consistency
    # - Services are stateless (except for injected context)
    #
    # @example Define a domain service
    #   class UserService < SmartDomain::Domain::Service
    #     def create_user(attributes)
    #       User.transaction do
    #         user = User.create!(attributes)
    #
    #         event = UserCreatedEvent.new(
    #           event_type: 'user.created',
    #           aggregate_id: user.id,
    #           aggregate_type: 'User',
    #           organization_id: current_organization_id,
    #           user_id: user.id,
    #           email: user.email
    #         )
    #
    #         publish_after_commit(event)
    #         user
    #       end
    #     end
    #   end
    #
    # @example Use the service in a controller
    #   class UsersController < ApplicationController
    #     def create
    #       service = UserService.new(
    #         current_user: current_user,
    #         organization_id: current_organization.id
    #       )
    #       @user = service.create_user(user_params)
    #       redirect_to @user, notice: 'User created successfully'
    #     end
    #   end
    class Service
      include PolicyHelpers

      attr_reader :current_user, :current_user_id, :current_organization_id, :logger

      # Initialize service with context
      #
      # @param current_user [Object, nil] Current user performing the action
      # @param current_user_id [String, Integer, nil] Current user ID
      # @param organization_id [String, Integer, nil] Organization/tenant ID
      # @param logger [Logger, nil] Logger instance (defaults to Rails.logger)
      def initialize(current_user: nil, current_user_id: nil, organization_id: nil, logger: nil)
        @current_user = current_user
        @current_user_id = current_user_id || current_user&.id
        @current_organization_id = organization_id || current_user&.organization_id
        @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new($stdout))
        @pending_events = []
      end

      # Publish event after the current transaction commits
      #
      # This ensures events are only published if the database transaction
      # succeeds. If the transaction rolls back, events are discarded.
      #
      # @param event [SmartDomain::Event::Base] Event to publish
      #
      # @example
      #   def create_user(attributes)
      #     User.transaction do
      #       user = User.create!(attributes)
      #       event = UserCreatedEvent.new(...)
      #       publish_after_commit(event)
      #       user
      #     end
      #   end
      def publish_after_commit(event)
        if active_record_available? && in_transaction?
          # Queue event for publishing after commit
          ActiveRecord::Base.connection.after_transaction_commit do
            publish_event(event)
          end
        else
          # No transaction, publish immediately
          publish_event(event)
        end
      end

      # Publish multiple events after commit
      #
      # @param events [Array<SmartDomain::Event::Base>] Events to publish
      def publish_all_after_commit(events)
        events.each { |event| publish_after_commit(event) }
      end

      # Run a block within a database transaction
      #
      # This is a convenience method for wrapping operations in a transaction.
      # Events should be published using #publish_after_commit within the block.
      #
      # @yield Block to run within transaction
      # @return [Object] Result of the block
      #
      # @example
      #   def transfer_funds(from_account, to_account, amount)
      #     with_transaction do
      #       from_account.withdraw(amount)
      #       to_account.deposit(amount)
      #
      #       event = FundsTransferredEvent.new(...)
      #       publish_after_commit(event)
      #
      #       true
      #     end
      #   end
      def with_transaction(&block)
        if active_record_available?
          ActiveRecord::Base.transaction(&block)
        else
          yield
        end
      end

      # Build event with common context fields
      #
      # This helper method reduces boilerplate by automatically filling in
      # organization_id and actor fields from the service context.
      #
      # @param event_class [Class] Event class to instantiate
      # @param attributes [Hash] Event attributes
      # @return [SmartDomain::Event::Base] Instantiated event
      #
      # @example
      #   event = build_event(UserCreatedEvent,
      #     event_type: 'user.created',
      #     aggregate_id: user.id,
      #     aggregate_type: 'User',
      #     user_id: user.id,
      #     email: user.email
      #   )
      def build_event(event_class, attributes = {})
        # Auto-fill organization_id if not provided
        attributes[:organization_id] ||= current_organization_id

        # Auto-fill actor fields if event includes ActorMixin
        if event_class.method_defined?(:actor_id)
          attributes[:actor_id] ||= current_user_id&.to_s
          attributes[:actor_email] ||= current_user&.email
        end

        event_class.new(attributes)
      end

      # Extract changes from an ActiveRecord model for ChangeTrackingMixin
      #
      # This helper extracts changed fields and their old/new values from
      # an ActiveRecord model's saved_changes.
      #
      # @param record [ActiveRecord::Base] Record with changes
      # @return [Hash] Hash with changed_fields, old_values, new_values
      #
      # @example
      #   user.update!(email: 'new@example.com', name: 'New Name')
      #   changes = extract_changes(user)
      #   # => {
      #   #   changed_fields: ['email', 'name'],
      #   #   old_values: { email: 'old@example.com', name: 'Old Name' },
      #   #   new_values: { email: 'new@example.com', name: 'New Name' }
      #   # }
      def extract_changes(record)
        return { changed_fields: [], old_values: {}, new_values: {} } unless record.respond_to?(:saved_changes)

        changes = record.saved_changes
        {
          changed_fields: changes.keys,
          old_values: changes.transform_values(&:first),
          new_values: changes.transform_values(&:last)
        }
      end

      # Log a message with service context
      #
      # @param level [Symbol] Log level (:info, :warn, :error, :debug)
      # @param message [String] Log message
      # @param data [Hash] Additional structured data
      def log(level, message, data = {})
        context = {
          service: self.class.name,
          organization_id: current_organization_id,
          user_id: current_user_id
        }.merge(data)

        @logger.send(level, "[#{self.class.name}] #{message} - #{context.to_json}")
      end

      private

      # Publish an event to the event bus
      # @param event [SmartDomain::Event::Base] Event to publish
      def publish_event(event)
        SmartDomain::Event.bus.publish(event)
      rescue StandardError => e
        @logger.error "[#{self.class.name}] Failed to publish event: #{e.message}"
        @logger.error e.backtrace.join("\n")
        raise
      end

      # Check if ActiveRecord is available
      # @return [Boolean]
      def active_record_available?
        defined?(ActiveRecord::Base)
      end

      # Check if currently in a database transaction
      # @return [Boolean]
      def in_transaction?
        return false unless active_record_available?

        ActiveRecord::Base.connection.transaction_open?
      end
    end
  end
end
