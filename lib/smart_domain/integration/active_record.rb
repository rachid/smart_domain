# frozen_string_literal: true

module SmartDomain
  module Integration
    # ActiveRecord integration for domain events.
    #
    # This module provides ActiveRecord models with the ability to queue
    # and publish domain events after transactions commit successfully.
    #
    # Key features:
    # - Events are queued during the request/transaction
    # - Events are published AFTER the database transaction commits
    # - If transaction rolls back, events are discarded
    # - Thread-safe event queue per model instance
    #
    # @example Include in a model
    #   class User < ApplicationRecord
    #     include SmartDomain::Integration::ActiveRecord
    #
    #     after_create :publish_created_event
    #     after_update :publish_updated_event
    #
    #     private
    #
    #     def publish_created_event
    #       add_domain_event(UserCreatedEvent.new(
    #         event_type: 'user.created',
    #         aggregate_id: id,
    #         aggregate_type: 'User',
    #         organization_id: organization_id,
    #         user_id: id,
    #         email: email
    #       ))
    #     end
    #
    #     def publish_updated_event
    #       add_domain_event(UserUpdatedEvent.new(
    #         event_type: 'user.updated',
    #         aggregate_id: id,
    #         aggregate_type: 'User',
    #         organization_id: organization_id,
    #         user_id: id,
    #         changed_fields: saved_changes.keys,
    #         old_values: saved_changes.transform_values(&:first),
    #         new_values: saved_changes.transform_values(&:last)
    #       ))
    #     end
    #   end
    module ActiveRecord
      extend ActiveSupport::Concern

      included do
        # Register after_commit callback to publish events
        after_commit :publish_domain_events

        # Register after_rollback callback to clear events
        after_rollback :clear_domain_events
      end

      # Queue a domain event for publishing after commit
      #
      # Events are stored in an instance variable and published
      # when the transaction commits successfully.
      #
      # @param event [SmartDomain::Event::Base] Event to queue
      #
      # @example
      #   user = User.new(email: 'test@example.com')
      #   user.save!
      #
      #   # In after_create callback
      #   event = UserCreatedEvent.new(...)
      #   add_domain_event(event)
      def add_domain_event(event)
        @pending_domain_events ||= []
        @pending_domain_events << event
      end

      # Queue multiple domain events
      #
      # @param events [Array<SmartDomain::Event::Base>] Events to queue
      def add_domain_events(events)
        events.each { |event| add_domain_event(event) }
      end

      # Get pending events (useful for debugging/testing)
      #
      # @return [Array<SmartDomain::Event::Base>] Queued events
      def pending_domain_events
        @pending_domain_events || []
      end

      # Build an event with automatic field population
      #
      # This helper automatically fills in common event fields from the model:
      # - aggregate_id: Uses model's id
      # - aggregate_type: Uses model's class name
      # - organization_id: Uses model's organization_id (if present)
      #
      # @param event_class [Class] Event class to instantiate
      # @param attributes [Hash] Additional event attributes
      # @return [SmartDomain::Event::Base] Instantiated event
      #
      # @example
      #   event = build_domain_event(UserCreatedEvent,
      #     event_type: 'user.created',
      #     user_id: id,
      #     email: email
      #   )
      #   add_domain_event(event)
      def build_domain_event(event_class, attributes = {})
        # Auto-fill aggregate fields
        attributes[:aggregate_id] ||= id.to_s
        attributes[:aggregate_type] ||= self.class.name

        # Auto-fill organization_id if model has it
        if respond_to?(:organization_id) && organization_id.present?
          attributes[:organization_id] ||= organization_id.to_s
        end

        event_class.new(attributes)
      end

      # Helper to extract changes for ChangeTrackingMixin
      #
      # @return [Hash] Hash with changed_fields, old_values, new_values
      def domain_event_changes
        return { changed_fields: [], old_values: {}, new_values: {} } unless respond_to?(:saved_changes)

        changes = saved_changes
        {
          changed_fields: changes.keys,
          old_values: changes.transform_values(&:first),
          new_values: changes.transform_values(&:last)
        }
      end

      private

      # Publish all pending events after commit
      #
      # This callback is automatically registered when the module is included.
      # It publishes all queued events to the event bus and clears the queue.
      def publish_domain_events
        return if @pending_domain_events.blank?

        @pending_domain_events.each do |event|
          SmartDomain::Event.bus.publish(event)
        rescue StandardError => e
          # Log error but don't raise (events should be fire-and-forget)
          logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
          logger.error "[SmartDomain] Failed to publish event: #{e.message}"
          logger.error e.backtrace.join("\n")
        end

        clear_domain_events
      end

      # Clear pending events
      #
      # Called after successful publish or after transaction rollback
      def clear_domain_events
        @pending_domain_events = []
      end
    end
  end
end
