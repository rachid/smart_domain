# frozen_string_literal: true

require 'active_model'
require 'active_support/core_ext/object/blank'
require 'securerandom'
require 'logger'

module SmartDomain
  module Event
    # Validation error for domain events
    class ValidationError < StandardError; end

    # Base class for all domain events in the system.
    #
    # Domain events represent significant business occurrences that other
    # parts of the system need to know about, such as user registrations,
    # order placements, or inventory changes.
    #
    # Events are immutable once created - all attributes are frozen.
    #
    # @example Define a custom event
    #   class UserCreatedEvent < SmartDomain::Event::Base
    #     attribute :user_id, :string
    #     attribute :email, :string
    #
    #     validates :user_id, :email, presence: true
    #   end
    #
    # @example Create and publish an event
    #   event = UserCreatedEvent.new(
    #     event_type: 'user.created',
    #     aggregate_id: user.id,
    #     aggregate_type: 'User',
    #     organization_id: org.id,
    #     user_id: user.id,
    #     email: user.email
    #   )
    #
    #   SmartDomain::Event.bus.publish(event)
    class Base
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations

      # Core event fields
      attribute :event_id, :string, default: -> { SecureRandom.uuid }
      attribute :event_type, :string
      attribute :aggregate_id, :string
      attribute :aggregate_type, :string
      attribute :organization_id, :string
      attribute :occurred_at, :datetime, default: -> { Time.current }
      attribute :version, :integer, default: 1
      attribute :correlation_id, :string
      attribute :causation_id, :string
      attribute :metadata, default: -> { {} }

      # Validate required fields
      validates :event_type, :aggregate_id, :aggregate_type, :organization_id, presence: true

      # Initialize event and freeze it (immutability)
      def initialize(attributes = {})
        super
        freeze_event
        return if valid?

        raise ValidationError, "Event validation failed: #{errors.full_messages.join(', ')}"
      end

      # Convert event to hash
      # @return [Hash] Event attributes as hash
      def to_h
        attributes.deep_symbolize_keys
      end

      # String representation
      # @return [String] Event representation
      def to_s
        "<#{self.class.name}(id=#{event_id}, type=#{event_type})>"
      end

      alias inspect to_s

      private

      # Freeze the event to make it immutable
      def freeze_event
        @attributes.freeze
        freeze
      end
    end

    # Event bus for publishing and subscribing to domain events.
    #
    # The event bus follows the publish-subscribe pattern, allowing
    # decoupled communication between different parts of the application.
    #
    # In production, this can be replaced with more robust message brokers
    # like Redis, RabbitMQ, or AWS EventBridge via adapters.
    #
    # @example Subscribe to events
    #   bus = SmartDomain::Event::Bus.new
    #   handler = UserEmailHandler.new
    #   bus.subscribe('user.created', handler)
    #
    # @example Publish an event
    #   event = UserCreatedEvent.new(...)
    #   bus.publish(event)
    class Bus
      attr_reader :adapter

      # Initialize event bus with optional adapter
      # @param adapter [Object, Symbol] Event bus adapter or adapter name (default: Memory adapter)
      def initialize(adapter: nil)
        @adapter = resolve_adapter(adapter)
      end

      def logger
        @logger ||= SmartDomain.configuration.logger
      end

      # Subscribe a handler to a specific event type
      # @param event_type [String] Event type to subscribe to (e.g., 'user.created')
      # @param handler [Object] Handler object that responds to #handle(event)
      def subscribe(event_type, handler)
        @adapter.subscribe(event_type, handler)
        logger.info "[SmartDomain] Event handler subscribed: #{handler.class.name} -> #{event_type}"
      end

      # Publish an event to all registered handlers
      # @param event [SmartDomain::Event::Base] Event to publish
      # @raise [ArgumentError] If event is invalid
      def publish(event)
        validate_event!(event)

        logger.info "[SmartDomain] Publishing event: #{event.event_type} (#{event.event_id})"
        logger.debug "[SmartDomain] Event details: #{event.to_h}"

        @adapter.publish(event)
      end

      private

      # Resolve adapter from symbol or object
      # @param adapter [Object, Symbol, nil] Adapter instance, symbol, or nil
      # @return [Object] Adapter instance
      def resolve_adapter(adapter)
        return Adapters::Memory.new if adapter.nil?
        return adapter unless adapter.is_a?(Symbol)

        case adapter
        when :memory
          Adapters::Memory.new
        else
          raise ArgumentError, "Unknown adapter: #{adapter}. Available adapters: :memory"
        end
      end

      # Validate event before publishing
      # @param event [Object] Event to validate
      # @raise [ArgumentError] If event is not a Base instance
      # @raise [ValidationError] If event validation fails
      def validate_event!(event)
        unless event.is_a?(Base)
          raise ArgumentError, "Event must be a SmartDomain::Event::Base, got #{event.class.name}"
        end

        begin
          return if event.valid?

          raise ValidationError, "Event validation failed: #{event.errors.full_messages.join(', ')}"
        rescue NoMethodError => e
          raise ValidationError, "Malformed event: #{e.message}"
        end
      end
    end

    # Global event bus singleton
    # @return [SmartDomain::Event::Bus] Global event bus instance
    def self.bus
      @bus ||= Bus.new(adapter: SmartDomain.configuration&.event_bus_adapter)
    end

    # Reset the global event bus (useful for testing)
    # @api private
    def self.reset_bus!
      @bus = nil
    end
  end
end
