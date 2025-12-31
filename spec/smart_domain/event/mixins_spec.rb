# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Event Mixins' do
  describe SmartDomain::Event::ActorMixin do
    class ActorEvent < SmartDomain::Event::Base
      include SmartDomain::Event::ActorMixin
    end

    it 'adds actor_id and actor_email attributes' do
      event = ActorEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        actor_id: 'user-456',
        actor_email: 'actor@example.com'
      )

      expect(event.actor_id).to eq('user-456')
      expect(event.actor_email).to eq('actor@example.com')
    end

    it 'validates presence of actor_id' do
      expect do
        ActorEvent.new(
          event_type: 'test.event',
          aggregate_id: '123',
          aggregate_type: 'Test',
          organization_id: 'org-1',
          actor_email: 'actor@example.com'
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Actor can't be blank/)
    end

    it 'allows optional actor_email' do
      event = ActorEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        actor_id: 'user-456'
      )

      expect(event.actor_id).to eq('user-456')
      expect(event.actor_email).to be_nil
    end
  end

  describe SmartDomain::Event::AuditMixin do
    class AuditMixinEvent < SmartDomain::Event::Base
      include SmartDomain::Event::AuditMixin

      attribute :action, :string
    end

    it 'adds occurred_at attribute' do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      event = AuditMixinEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        action: 'create'
      )

      expect(event.occurred_at).to eq(freeze_time)
    end

    it 'allows custom occurred_at' do
      custom_time = Time.now - 3600

      event = AuditMixinEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        action: 'create',
        occurred_at: custom_time
      )

      expect(event.occurred_at).to eq(custom_time)
    end
  end

  describe SmartDomain::Event::ChangeTrackingMixin do
    class ChangeEvent < SmartDomain::Event::Base
      include SmartDomain::Event::ChangeTrackingMixin
    end

    it 'adds change tracking attributes' do
      event = ChangeEvent.new(
        event_type: 'test.updated',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        changed_fields: %w[name email],
        old_values: { name: 'Old Name', email: 'old@example.com' },
        new_values: { name: 'New Name', email: 'new@example.com' }
      )

      expect(event.changed_fields).to eq(%w[name email])
      expect(event.old_values).to eq({ name: 'Old Name', email: 'old@example.com' })
      expect(event.new_values).to eq({ name: 'New Name', email: 'new@example.com' })
    end

    it 'validates presence of changed_fields' do
      expect do
        ChangeEvent.new(
          event_type: 'test.updated',
          aggregate_id: '123',
          aggregate_type: 'Test',
          organization_id: 'org-1',
          old_values: { name: 'Old' },
          new_values: { name: 'New' }
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Changed fields can't be blank/)
    end

    it 'allows empty old_values and new_values hashes' do
      event = ChangeEvent.new(
        event_type: 'test.updated',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        changed_fields: ['name'],
        old_values: {},
        new_values: {}
      )

      expect(event.old_values).to eq({})
      expect(event.new_values).to eq({})
    end

    it 'defaults to empty hashes for old_values and new_values' do
      event = ChangeEvent.new(
        event_type: 'test.updated',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        changed_fields: ['name']
      )

      expect(event.old_values).to eq({})
      expect(event.new_values).to eq({})
    end
  end

  describe SmartDomain::Event::SecurityContextMixin do
    class SecurityEvent < SmartDomain::Event::Base
      include SmartDomain::Event::SecurityContextMixin
    end

    it 'adds ip_address and user_agent attributes' do
      event = SecurityEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      )

      expect(event.ip_address).to eq('192.168.1.1')
      expect(event.user_agent).to eq('Mozilla/5.0')
    end

    it 'allows optional ip_address and user_agent' do
      event = SecurityEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1'
      )

      expect(event.ip_address).to be_nil
      expect(event.user_agent).to be_nil
    end
  end

  describe SmartDomain::Event::ReasonMixin do
    class ReasonEvent < SmartDomain::Event::Base
      include SmartDomain::Event::ReasonMixin
    end

    it 'adds reason attribute' do
      event = ReasonEvent.new(
        event_type: 'test.event',
        aggregate_id: '123',
        aggregate_type: 'Test',
        organization_id: 'org-1',
        reason: 'User requested account deletion'
      )

      expect(event.reason).to eq('User requested account deletion')
    end

    it 'validates presence of reason' do
      expect do
        ReasonEvent.new(
          event_type: 'test.event',
          aggregate_id: '123',
          aggregate_type: 'Test',
          organization_id: 'org-1'
        )
      end.to raise_error(SmartDomain::Event::ValidationError, /Reason can't be blank/)
    end
  end

  describe 'Combining multiple mixins' do
    class CompleteEvent < SmartDomain::Event::Base
      include SmartDomain::Event::ActorMixin
      include SmartDomain::Event::AuditMixin
      include SmartDomain::Event::ChangeTrackingMixin
      include SmartDomain::Event::SecurityContextMixin
      include SmartDomain::Event::ReasonMixin
    end

    it 'supports all mixins together' do
      event = CompleteEvent.new(
        event_type: 'user.updated',
        aggregate_id: 'user-123',
        aggregate_type: 'User',
        organization_id: 'org-456',
        actor_id: 'admin-789',
        actor_email: 'admin@example.com',
        changed_fields: ['email'],
        old_values: { email: 'old@example.com' },
        new_values: { email: 'new@example.com' },
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0',
        reason: 'User requested email change'
      )

      expect(event.actor_id).to eq('admin-789')
      expect(event.actor_email).to eq('admin@example.com')
      expect(event.occurred_at).to be_a(Time)
      expect(event.changed_fields).to eq(['email'])
      expect(event.old_values).to eq({ email: 'old@example.com' })
      expect(event.new_values).to eq({ email: 'new@example.com' })
      expect(event.ip_address).to eq('192.168.1.1')
      expect(event.user_agent).to eq('Mozilla/5.0')
      expect(event.reason).to eq('User requested email change')
    end

    it 'validates all required fields from mixins' do
      expect do
        CompleteEvent.new(
          event_type: 'user.updated',
          aggregate_id: 'user-123',
          aggregate_type: 'User',
          organization_id: 'org-456'
          # Missing: actor_id, changed_fields, reason
        )
      end.to raise_error(SmartDomain::Event::ValidationError)
    end
  end
end
