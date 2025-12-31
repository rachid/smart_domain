# frozen_string_literal: true

require "spec_helper"

RSpec.describe SmartDomain::Handlers::MetricsHandler do
  let(:handler) { described_class.new("user") }

  # Test event
  class MetricsTestEvent < SmartDomain::Event::Base
    attribute :user_id, :string
    attribute :duration, :float
  end

  describe "#can_handle?" do
    it "handles events matching its domain" do
      expect(handler.can_handle?("user.created")).to be true
      expect(handler.can_handle?("user.updated")).to be true
      expect(handler.can_handle?("user.deleted")).to be true
    end

    it "does not handle events from other domains" do
      expect(handler.can_handle?("product.created")).to be false
      expect(handler.can_handle?("order.placed")).to be false
    end

    it "handles wildcard domain pattern" do
      wildcard_handler = described_class.new("*")
      expect(wildcard_handler.can_handle?("user.created")).to be true
      expect(wildcard_handler.can_handle?("product.created")).to be true
    end
  end

  describe "#handle" do
    let(:event) do
      MetricsTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        user_id: "user-123"
      )
    end

    it "increments counter for event type" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      expect(logger).to receive(:info) do |message|
        expect(message).to include("METRIC")
        expect(message).to include("domain_events.user.created")
        expect(message).to include("aggregate_type")
      end

      handler.handle(event)
    end

    it "tracks timing when duration is present" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      timed_event = MetricsTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        user_id: "user-123",
        duration: 150.5
      )

      expect(logger).to receive(:info).with(/METRIC/).twice

      handler.handle(timed_event)
    end

    it "includes organization_id in metrics tags" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      expect(logger).to receive(:info) do |message|
        expect(message).to include("org-456")
        expect(message).to include("organization_id")
      end

      handler.handle(event)
    end

    it "handles errors gracefully" do
      allow_any_instance_of(described_class).to receive(:emit_metric).and_raise(StandardError, "Metrics error")

      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)
      allow(logger).to receive(:warn)

      # Should not raise
      expect { handler.handle(event) }.not_to raise_error
    end
  end

  describe "metrics collection" do
    it "collects metrics for multiple events" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      event1 = MetricsTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-1",
        aggregate_type: "User",
        organization_id: "org-1",
        user_id: "user-1"
      )

      event2 = MetricsTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-2",
        aggregate_type: "User",
        organization_id: "org-1",
        user_id: "user-2"
      )

      expect(logger).to receive(:info).with(/METRIC/).twice

      handler.handle(event1)
      handler.handle(event2)
    end

    it "supports different event types" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      create_event = MetricsTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-1",
        aggregate_type: "User",
        organization_id: "org-1",
        user_id: "user-1"
      )

      update_event = MetricsTestEvent.new(
        event_type: "user.updated",
        aggregate_id: "user-1",
        aggregate_type: "User",
        organization_id: "org-1",
        user_id: "user-1"
      )

      delete_event = MetricsTestEvent.new(
        event_type: "user.deleted",
        aggregate_id: "user-1",
        aggregate_type: "User",
        organization_id: "org-1",
        user_id: "user-1"
      )

      expect(logger).to receive(:info).with(/user.created/)
      expect(logger).to receive(:info).with(/user.updated/)
      expect(logger).to receive(:info).with(/user.deleted/)

      handler.handle(create_event)
      handler.handle(update_event)
      handler.handle(delete_event)
    end
  end

  describe "integration with metrics backends" do
    let(:event) do
      MetricsTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        user_id: "user-123"
      )
    end

    it "logs metrics in structured format" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      expect(logger).to receive(:info) do |message|
        # Should be parseable as structured log
        expect(message).to include("METRIC")
        expect(message).to include("domain_events.user.created")
        expect(message).to include("aggregate_type")
        expect(message).to include("organization_id")
      end

      handler.handle(event)
    end

    it "provides metrics data for external systems" do
      # This test verifies the handler provides data in a format
      # that can be consumed by StatsD, Datadog, Prometheus, etc.

      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      expect(logger).to receive(:info) do |message|
        # Format should include:
        # - Metric name (event_type)
        # - Tags (organization_id, aggregate_type)
        expect(message).to match(/domain_events\.user\.created/)
        expect(message).to match(/org-456/)
        expect(message).to match(/User/)
      end

      handler.handle(event)
    end
  end
end
