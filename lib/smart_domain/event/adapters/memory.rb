# frozen_string_literal: true

module SmartDomain
  module Event
    module Adapters
      # In-memory event bus adapter for synchronous event handling.
      #
      # This adapter stores event handlers in memory and publishes events
      # synchronously. It's suitable for development, testing, and simple
      # production applications.
      #
      # For more robust production use cases, consider Redis or ActiveJob adapters.
      #
      # @example
      #   adapter = SmartDomain::Event::Adapters::Memory.new
      #   adapter.subscribe('user.created', handler)
      #   adapter.publish(event)
      class Memory
        def initialize
          @handlers = Hash.new { |h, k| h[k] = [] }
          @logger = ActiveSupport::TaggedLogging.new(Logger.new($stdout))
        end

        # Subscribe a handler to an event type
        # @param event_type [String] Event type to subscribe to
        # @param handler [Object] Handler that responds to #handle(event)
        def subscribe(event_type, handler)
          @handlers[event_type] << handler unless @handlers[event_type].include?(handler)
        end

        # Publish an event to all subscribed handlers
        # @param event [SmartDomain::Event::Base] Event to publish
        def publish(event)
          # Find all matching handlers (exact match + wildcard patterns)
          matching_handlers = find_matching_handlers(event.event_type)

          if matching_handlers.empty?
            @logger.debug "[SmartDomain::Memory] No handlers for event type: #{event.event_type}"
            return
          end

          @logger.debug "[SmartDomain::Memory] Notifying #{matching_handlers.size} handler(s) for #{event.event_type}"

          matching_handlers.each do |handler|
            handle_event(handler, event)
          end
        end

        # Get all registered handlers for an event type
        # @param event_type [String] Event type
        # @return [Array<Object>] List of handlers
        def handlers_for(event_type)
          @handlers[event_type]
        end

        # Clear all handlers (useful for testing)
        # @api private
        def clear!
          @handlers.clear
        end

        private

        # Find all handlers matching the given event type
        # Supports exact matches and wildcard patterns (e.g., "user.*")
        # @param event_type [String] Event type to match
        # @return [Array<Object>] List of matching handlers
        def find_matching_handlers(event_type)
          handlers = []

          @handlers.each do |pattern, pattern_handlers|
            if event_type_matches?(event_type, pattern)
              handlers.concat(pattern_handlers)
            end
          end

          handlers.uniq
        end

        # Check if event type matches a subscription pattern
        # @param event_type [String] Event type to check
        # @param pattern [String] Subscription pattern (may include wildcards)
        # @return [Boolean] True if event type matches pattern
        def event_type_matches?(event_type, pattern)
          # Exact match
          return true if event_type == pattern

          # Wildcard pattern match (e.g., "user.*" matches "user.created")
          if pattern.end_with?(".*")
            prefix = pattern[0..-3] # Remove ".*"
            return event_type.start_with?("#{prefix}.")
          end

          false
        end

        # Handle event with error isolation
        # @param handler [Object] Handler to execute
        # @param event [SmartDomain::Event::Base] Event to handle
        def handle_event(handler, event)
          handler.handle(event)
        rescue StandardError => e
          @logger.error "[SmartDomain::Memory] Handler #{handler.class.name} failed: #{e.message}"
          @logger.error e.backtrace.join("\n")
          # Swallow exception to not affect other handlers
        end
      end
    end
  end
end
