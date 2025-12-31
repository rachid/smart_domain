# frozen_string_literal: true

require "spec_helper"

RSpec.describe SmartDomain::Event::Base do
  # Test event class
  class TestEvent < SmartDomain::Event::Base
    attribute :user_id, :string
    attribute :email, :string

    validates :user_id, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  end

  describe "initialization" do
    it "creates a valid event with required attributes" do
      event = TestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        user_id: "user-123",
        email: "test@example.com"
      )

      expect(event.event_id).to be_a(String)
      expect(event.event_type).to eq("user.created")
      expect(event.aggregate_id).to eq("user-123")
      expect(event.aggregate_type).to eq("User")
      expect(event.organization_id).to eq("org-456")
      expect(event.user_id).to eq("user-123")
      expect(event.email).to eq("test@example.com")
      expect(event.occurred_at).to be_a(Time)
      expect(event.version).to eq(1)
    end

    it "generates a unique event_id" do
      event1 = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      event2 = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      expect(event1.event_id).not_to eq(event2.event_id)
    end

    it "sets occurred_at to current time" do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      event = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      expect(event.occurred_at).to eq(freeze_time)
    end

    it "allows setting custom event_id" do
      custom_id = "custom-event-id"
      event = TestEvent.new(
        event_id: custom_id,
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      expect(event.event_id).to eq(custom_id)
    end

    it "supports correlation_id and causation_id" do
      event = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        correlation_id: "correlation-123",
        causation_id: "causation-456",
        user_id: "user-1",
        email: "test@example.com"
      )

      expect(event.correlation_id).to eq("correlation-123")
      expect(event.causation_id).to eq("causation-456")
    end

    it "supports metadata hash" do
      metadata = { source: "api", ip_address: "127.0.0.1" }
      event = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        metadata: metadata,
        user_id: "user-1",
        email: "test@example.com"
      )

      expect(event.metadata).to eq(metadata)
    end
  end

  describe "immutability" do
    it "freezes the event after initialization" do
      event = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      expect(event).to be_frozen
    end

    it "prevents modification of attributes" do
      event = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      expect do
        event.event_type = "modified.event"
      end.to raise_error(FrozenError)
    end
  end

  describe "validation" do
    it "raises error for missing event_type" do
      expect do
        TestEvent.new(
          aggregate_id: "123",
          aggregate_type: "Test",
          organization_id: "org-1",
          user_id: "user-1",
          email: "test@example.com"
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Event type can't be blank/)
    end

    it "raises error for missing aggregate_id" do
      expect do
        TestEvent.new(
          event_type: "test.event",
          aggregate_type: "Test",
          organization_id: "org-1",
          user_id: "user-1",
          email: "test@example.com"
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Aggregate can't be blank/)
    end

    it "raises error for missing aggregate_type" do
      expect do
        TestEvent.new(
          event_type: "test.event",
          aggregate_id: "123",
          organization_id: "org-1",
          user_id: "user-1",
          email: "test@example.com"
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Aggregate can't be blank/)
    end

    it "raises error for invalid custom validations" do
      expect do
        TestEvent.new(
          event_type: "test.event",
          aggregate_id: "123",
          aggregate_type: "Test",
          organization_id: "org-1",
          user_id: "user-1",
          email: "invalid-email"
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Email is invalid/)
    end
  end

  describe "#to_h" do
    it "returns hash representation of event" do
      event = TestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )

      hash = event.to_h

      expect(hash).to include(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        user_id: "user-1",
        email: "test@example.com"
      )
      expect(hash[:event_id]).to be_a(String)
      expect(hash[:occurred_at]).to be_a(Time)
    end
  end
end

RSpec.describe SmartDomain::Event::Bus do
  let(:bus) { described_class.new }

  # Test handler
  class TestHandler < SmartDomain::Event::Handler
    attr_reader :handled_events

    def initialize
      @handled_events = []
    end

    def can_handle?(event_type)
      event_type.start_with?("test.")
    end

    def handle(event)
      @handled_events << event
    end
  end

  # Test event
  class SimpleEvent < SmartDomain::Event::Base
    attribute :message, :string
  end

  describe "#subscribe" do
    it "subscribes a handler to an event type" do
      handler = TestHandler.new
      bus.subscribe("test.event", handler)

      expect(bus.adapter.instance_variable_get(:@handlers)["test.event"]).to include(handler)
    end

    it "allows multiple handlers for the same event type" do
      handler1 = TestHandler.new
      handler2 = TestHandler.new
      bus.subscribe("test.event", handler1)
      bus.subscribe("test.event", handler2)

      subscribers = bus.adapter.instance_variable_get(:@handlers)["test.event"]
      expect(subscribers).to include(handler1, handler2)
    end

    it "supports wildcard subscriptions with *" do
      handler = TestHandler.new
      bus.subscribe("test.*", handler)

      event = SimpleEvent.new(
        event_type: "test.created",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      bus.publish(event)
      expect(handler.handled_events).to include(event)
    end
  end

  describe "#publish" do
    it "publishes event to subscribed handlers" do
      handler = TestHandler.new
      bus.subscribe("test.event", handler)

      event = SimpleEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      bus.publish(event)

      expect(handler.handled_events).to include(event)
    end

    it "validates event before publishing" do
      handler = TestHandler.new
      bus.subscribe("test.event", handler)

      # Create invalid event (missing required fields)
      invalid_event = SimpleEvent.allocate # Skip initialization

      expect do
        bus.publish(invalid_event)
      end.to raise_error(SmartDomain::Event::ValidationError)
    end

    it "isolates handler errors" do
      failing_handler = Class.new(SmartDomain::Event::Handler) do
        def can_handle?(event_type)
          true
        end

        def handle(_event)
          raise StandardError, "Handler failed"
        end
      end.new

      successful_handler = TestHandler.new

      bus.subscribe("test.event", failing_handler)
      bus.subscribe("test.event", successful_handler)

      event = SimpleEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      # Should not raise, and successful handler should still process
      expect { bus.publish(event) }.not_to raise_error
      expect(successful_handler.handled_events).to include(event)
    end

    it "logs published events" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      event = SimpleEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      expect(logger).to receive(:info).with(/Publishing event: test.event/)

      bus.publish(event)
    end
  end

  describe "singleton bus" do
    it "provides a global event bus" do
      bus1 = SmartDomain::Event.bus
      bus2 = SmartDomain::Event.bus

      expect(bus1).to eq(bus2)
      expect(bus1).to be_a(SmartDomain::Event::Bus)
    end
  end
end
