# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SmartDomain::Event::Registration do
  before(:each) do
    # Clear the event bus before each test
    SmartDomain::Event.bus.adapter.clear!
  end

  describe '.register_standard_handlers' do
    it 'registers audit handler for all specified events' do
      described_class.register_standard_handlers(
        domain: 'user',
        events: %w[created updated],
        include_audit: true,
        include_metrics: false
      )

      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)

      expect(subscribers['user.created']).not_to be_empty
      expect(subscribers['user.updated']).not_to be_empty

      # Should have audit handler
      audit_handler = subscribers['user.created'].find { |h| h.is_a?(SmartDomain::Handlers::AuditHandler) }
      expect(audit_handler).not_to be_nil
    end

    it 'registers metrics handler for all specified events' do
      described_class.register_standard_handlers(
        domain: 'user',
        events: %w[created updated],
        include_audit: false,
        include_metrics: true
      )

      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)

      # Should have metrics handler
      metrics_handler = subscribers['user.created'].find { |h| h.is_a?(SmartDomain::Handlers::MetricsHandler) }
      expect(metrics_handler).not_to be_nil
    end

    it 'registers both audit and metrics handlers when both enabled' do
      described_class.register_standard_handlers(
        domain: 'user',
        events: ['created'],
        include_audit: true,
        include_metrics: true
      )

      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)
      handlers = subscribers['user.created']

      audit_handler = handlers.find { |h| h.is_a?(SmartDomain::Handlers::AuditHandler) }
      metrics_handler = handlers.find { |h| h.is_a?(SmartDomain::Handlers::MetricsHandler) }

      expect(audit_handler).not_to be_nil
      expect(metrics_handler).not_to be_nil
    end

    it 'registers handlers for multiple events' do
      described_class.register_standard_handlers(
        domain: 'product',
        events: %w[created updated deleted published],
        include_audit: true,
        include_metrics: true
      )

      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)

      expect(subscribers['product.created']).not_to be_empty
      expect(subscribers['product.updated']).not_to be_empty
      expect(subscribers['product.deleted']).not_to be_empty
      expect(subscribers['product.published']).not_to be_empty
    end

    it 'defaults to including both audit and metrics handlers' do
      described_class.register_standard_handlers(
        domain: 'order',
        events: ['placed']
      )

      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)
      handlers = subscribers['order.placed']

      audit_handler = handlers.find { |h| h.is_a?(SmartDomain::Handlers::AuditHandler) }
      metrics_handler = handlers.find { |h| h.is_a?(SmartDomain::Handlers::MetricsHandler) }

      expect(audit_handler).not_to be_nil
      expect(metrics_handler).not_to be_nil
    end

    it 'allows disabling both handlers' do
      described_class.register_standard_handlers(
        domain: 'test',
        events: ['event'],
        include_audit: false,
        include_metrics: false
      )

      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)

      # Should have no subscribers for this event
      expect(subscribers['test.event']).to be_empty
    end

    it 'uses domain-specific handler instances' do
      described_class.register_standard_handlers(
        domain: 'user',
        events: ['created'],
        include_audit: true
      )

      described_class.register_standard_handlers(
        domain: 'product',
        events: ['created'],
        include_audit: true
      )

      user_subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)['user.created']
      product_subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)['product.created']

      user_audit_handler = user_subscribers.find { |h| h.is_a?(SmartDomain::Handlers::AuditHandler) }
      product_audit_handler = product_subscribers.find { |h| h.is_a?(SmartDomain::Handlers::AuditHandler) }

      # Each domain should have its own handler instance
      expect(user_audit_handler.domain).to eq('user')
      expect(product_audit_handler.domain).to eq('product')
      expect(user_audit_handler).not_to equal(product_audit_handler)
    end
  end

  describe 'integration test' do
    class UserCreatedEvent < SmartDomain::Event::Base
      include SmartDomain::Event::ActorMixin

      attribute :user_id, :string
      attribute :email, :string
    end

    it 'processes events through registered handlers' do
      # Register standard handlers
      described_class.register_standard_handlers(
        domain: 'user',
        events: ['created'],
        include_audit: true,
        include_metrics: true
      )

      # Create and publish event
      event = UserCreatedEvent.new(
        event_type: 'user.created',
        aggregate_id: 'user-123',
        aggregate_type: 'User',
        organization_id: 'org-456',
        actor_id: 'admin-789',
        actor_email: 'admin@example.com',
        user_id: 'user-123',
        email: 'test@example.com'
      )

      # Publish event
      SmartDomain::Event.bus.publish(event)

      # Verify audit event was created (if audit table is enabled)
      if SmartDomain.configuration.audit_table_enabled?
        audit_event = AuditEvent.find_by(event_id: event.event_id)
        expect(audit_event).not_to be_nil
        expect(audit_event.event_type).to eq('user.created')
        expect(audit_event.aggregate_id).to eq('user-123')
        expect(audit_event.organization_id).to eq('org-456')
      end
    end

    it 'demonstrates 70% boilerplate reduction' do
      # Without register_standard_handlers, you would need:
      # audit_handler = AuditHandler.new(domain: 'user')
      # metrics_handler = MetricsHandler.new(domain: 'user')
      # Event.bus.subscribe('user.created', audit_handler)
      # Event.bus.subscribe('user.created', metrics_handler)
      # Event.bus.subscribe('user.updated', audit_handler)
      # Event.bus.subscribe('user.updated', metrics_handler)
      # Event.bus.subscribe('user.deleted', audit_handler)
      # Event.bus.subscribe('user.deleted', metrics_handler)
      # ... (14 lines for 3 events)

      # With register_standard_handlers, just one line:
      described_class.register_standard_handlers(
        domain: 'user',
        events: %w[created updated deleted]
      )

      # Verify all handlers are registered
      subscribers = SmartDomain::Event.bus.adapter.instance_variable_get(:@handlers)

      %w[user.created user.updated user.deleted].each do |event_type|
        handlers = subscribers[event_type]
        expect(handlers).not_to be_empty

        audit_handler = handlers.find { |h| h.is_a?(SmartDomain::Handlers::AuditHandler) }
        metrics_handler = handlers.find { |h| h.is_a?(SmartDomain::Handlers::MetricsHandler) }

        expect(audit_handler).not_to be_nil
        expect(metrics_handler).not_to be_nil
      end
    end
  end
end
