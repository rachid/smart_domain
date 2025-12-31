# frozen_string_literal: true

module SmartDomain
  module Event
    # Base class for event handlers.
    #
    # Event handlers process domain events and trigger side effects like
    # sending emails, updating read models, logging, or triggering workflows.
    #
    # Handlers must implement the #handle method.
    #
    # @example Define a custom handler
    #   class UserEmailHandler < SmartDomain::Event::Handler
    #     def handle(event)
    #       case event.event_type
    #       when 'user.created'
    #         UserMailer.welcome_email(event.user_id).deliver_later
    #       when 'user.activated'
    #         UserMailer.account_activated(event.user_id).deliver_later
    #       end
    #     end
    #
    #     def can_handle?(event_type)
    #       ['user.created', 'user.activated'].include?(event_type)
    #     end
    #   end
    #
    # @example Subscribe the handler
    #   handler = UserEmailHandler.new
    #   SmartDomain::Event.bus.subscribe('user.created', handler)
    #   SmartDomain::Event.bus.subscribe('user.activated', handler)
    class Handler
      # Handle a domain event
      #
      # Subclasses must implement this method to process events.
      #
      # @param event [SmartDomain::Event::Base] Event to handle
      # @raise [NotImplementedError] If not implemented by subclass
      def handle(event)
        raise NotImplementedError, "#{self.class.name} must implement #handle(event)"
      end

      # Check if this handler can handle a specific event type
      #
      # Subclasses should implement this for filtering events.
      # The default implementation returns true for all events.
      #
      # @param event_type [String] Event type to check
      # @return [Boolean] True if handler can handle this event type
      def can_handle?(event_type)
        raise NotImplementedError, "#{self.class.name} must implement #can_handle?(event_type)"
      end

      # Handle event asynchronously using ActiveJob
      #
      # This method queues the event handling in a background job.
      # Requires ActiveJob to be configured in the Rails application.
      #
      # @param event [SmartDomain::Event::Base] Event to handle
      # @raise [RuntimeError] If ActiveJob is not loaded
      def handle_async(event)
        unless defined?(ActiveJob)
          raise "ActiveJob is required for async event handling. Please require 'active_job' in your application."
        end

        event.validate!
        HandlerJob.perform_later(self.class.name, event.to_h)
      end
    end

    # ActiveJob for asynchronous event handling
    #
    # This job handles events in the background, allowing the main
    # request thread to continue without waiting for handlers to complete.
    #
    # @api private
    if defined?(ActiveJob)
      class HandlerJob < ActiveJob::Base
        queue_as :default

        # Perform asynchronous event handling
        # @param handler_class_name [String] Handler class name
        # @param event_data [Hash] Event data
        def perform(handler_class_name, event_data)
          handler = handler_class_name.constantize.new
          event_class = event_data[:event_type].camelize.constantize
          event = event_class.new(event_data)

          handler.handle(event)
        rescue StandardError => e
          Rails.logger.error "[SmartDomain] Async handler failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          raise
        end
      end
    end
  end
end
