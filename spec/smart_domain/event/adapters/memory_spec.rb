# frozen_string_literal: true

require "spec_helper"

RSpec.describe SmartDomain::Event::Adapters::Memory do
  let(:adapter) { described_class.new }

  # Test handler
  class MemoryTestHandler < SmartDomain::Event::Handler
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
  class MemoryAdapterTestEvent < SmartDomain::Event::Base
    attribute :message, :string
  end

  describe "#subscribe" do
    it "subscribes a handler to an event type" do
      handler = MemoryTestHandler.new
      adapter.subscribe("test.event", handler)

      subscribers = adapter.instance_variable_get(:@handlers)
      expect(subscribers["test.event"]).to include(handler)
    end

    it "allows multiple handlers for the same event type" do
      handler1 = MemoryTestHandler.new
      handler2 = MemoryTestHandler.new

      adapter.subscribe("test.event", handler1)
      adapter.subscribe("test.event", handler2)

      subscribers = adapter.instance_variable_get(:@handlers)
      expect(subscribers["test.event"]).to contain_exactly(handler1, handler2)
    end

    it "maintains separate subscriptions for different event types" do
      handler1 = MemoryTestHandler.new
      handler2 = MemoryTestHandler.new

      adapter.subscribe("test.created", handler1)
      adapter.subscribe("test.updated", handler2)

      subscribers = adapter.instance_variable_get(:@handlers)
      expect(subscribers["test.created"]).to eq([handler1])
      expect(subscribers["test.updated"]).to eq([handler2])
    end
  end

  describe "#publish" do
    it "publishes event to subscribed handlers" do
      handler = MemoryTestHandler.new
      adapter.subscribe("test.event", handler)

      event = MemoryAdapterTestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      adapter.publish(event)

      expect(handler.handled_events).to include(event)
    end

    it "publishes to all matching handlers" do
      handler1 = MemoryTestHandler.new
      handler2 = MemoryTestHandler.new
      handler3 = MemoryTestHandler.new

      adapter.subscribe("test.event", handler1)
      adapter.subscribe("test.event", handler2)
      adapter.subscribe("other.event", handler3)

      event = MemoryAdapterTestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      adapter.publish(event)

      expect(handler1.handled_events).to include(event)
      expect(handler2.handled_events).to include(event)
      expect(handler3.handled_events).to be_empty
    end

    it "supports wildcard subscriptions" do
      handler = MemoryTestHandler.new
      adapter.subscribe("test.*", handler)

      event1 = MemoryAdapterTestEvent.new(
        event_type: "test.created",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "created"
      )

      event2 = MemoryAdapterTestEvent.new(
        event_type: "test.updated",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "updated"
      )

      adapter.publish(event1)
      adapter.publish(event2)

      expect(handler.handled_events).to include(event1, event2)
    end

    it "validates events before publishing" do
      handler = MemoryTestHandler.new
      adapter.subscribe("test.event", handler)

      invalid_event = MemoryAdapterTestEvent.allocate # Skip initialization

      expect do
        adapter.publish(invalid_event)
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

      successful_handler = MemoryTestHandler.new

      adapter.subscribe("test.event", failing_handler)
      adapter.subscribe("test.event", successful_handler)

      event = MemoryAdapterTestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      # Should not raise, successful handler should still process
      expect { adapter.publish(event) }.not_to raise_error
      expect(successful_handler.handled_events).to include(event)
    end

    it "logs handler errors" do
      failing_handler = Class.new(SmartDomain::Event::Handler) do
        def can_handle?(event_type)
          true
        end

        def handle(_event)
          raise StandardError, "Handler failed"
        end
      end.new

      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)

      adapter.subscribe("test.event", failing_handler)

      event = MemoryAdapterTestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      expect(logger).to receive(:error).with(/Error in event handler/)

      adapter.publish(event)
    end

    it "logs published events" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      event = MemoryAdapterTestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      expect(logger).to receive(:info).with(/Publishing event: test.event/)

      adapter.publish(event)
    end
  end

  describe "synchronous execution" do
    it "executes handlers synchronously" do
      execution_order = []

      handler1 = Class.new(SmartDomain::Event::Handler) do
        define_method(:can_handle?) { |_| true }
        define_method(:handle) do |_event|
          execution_order << :handler1
          sleep 0.01
        end
      end.new

      handler2 = Class.new(SmartDomain::Event::Handler) do
        define_method(:can_handle?) { |_| true }
        define_method(:handle) do |_event|
          execution_order << :handler2
        end
      end.new

      adapter.subscribe("test.event", handler1)
      adapter.subscribe("test.event", handler2)

      event = MemoryAdapterTestEvent.new(
        event_type: "test.event",
        aggregate_id: "123",
        aggregate_type: "Test",
        organization_id: "org-1",
        message: "hello"
      )

      adapter.publish(event)

      # Handler2 should only execute after handler1 completes
      expect(execution_order).to eq([:handler1, :handler2])
    end
  end
end
