# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SmartDomain::Event::Handler do
  # Concrete handler for testing
  class ConcreteHandler < SmartDomain::Event::Handler
    attr_reader :handled_events

    def initialize
      @handled_events = []
    end

    def can_handle?(event_type)
      event_type.start_with?('user.')
    end

    def handle(event)
      @handled_events << event
    end
  end

  # Test event
  class UserEvent < SmartDomain::Event::Base
    attribute :user_id, :string
  end

  describe '#handle' do
    it 'must be implemented by subclasses' do
      handler = described_class.new

      event = UserEvent.new(
        event_type: 'user.created',
        aggregate_id: '123',
        aggregate_type: 'User',
        organization_id: 'org-1',
        user_id: 'user-123'
      )

      expect do
        handler.handle(event)
      end.to raise_error(NotImplementedError, /Subclasses must implement #handle/)
    end

    it 'processes events in concrete implementations' do
      handler = ConcreteHandler.new

      event = UserEvent.new(
        event_type: 'user.created',
        aggregate_id: '123',
        aggregate_type: 'User',
        organization_id: 'org-1',
        user_id: 'user-123'
      )

      handler.handle(event)

      expect(handler.handled_events).to include(event)
    end
  end

  describe '#can_handle?' do
    it 'must be implemented by subclasses' do
      handler = described_class.new

      expect do
        handler.can_handle?('user.created')
      end.to raise_error(NotImplementedError, /Subclasses must implement #can_handle?/)
    end

    it 'filters events in concrete implementations' do
      handler = ConcreteHandler.new

      expect(handler.can_handle?('user.created')).to be true
      expect(handler.can_handle?('user.updated')).to be true
      expect(handler.can_handle?('product.created')).to be false
    end
  end

  describe '#handle_async' do
    it 'enqueues event for async processing via ActiveJob' do
      skip 'ActiveJob not loaded in test environment' unless defined?(ActiveJob)

      handler = ConcreteHandler.new

      event = UserEvent.new(
        event_type: 'user.created',
        aggregate_id: '123',
        aggregate_type: 'User',
        organization_id: 'org-1',
        user_id: 'user-123'
      )

      expect(SmartDomain::Event::HandlerJob).to receive(:perform_later).with(
        handler.class.name,
        event.to_h
      )

      handler.handle_async(event)
    end

    it 'validates event before enqueueing' do
      skip 'ActiveJob not loaded in test environment' unless defined?(ActiveJob)

      handler = ConcreteHandler.new
      invalid_event = UserEvent.allocate # Skip initialization

      expect do
        handler.handle_async(invalid_event)
      end.to raise_error(SmartDomain::Event::ValidationError)
    end
  end
end
