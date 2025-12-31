# frozen_string_literal: true

require "spec_helper"

RSpec.describe SmartDomain::Handlers::AuditHandler do
  let(:handler) { described_class.new("user") }

  # Test event
  class AuditTestEvent < SmartDomain::Event::Base
    include SmartDomain::Event::ActorMixin
    attribute :user_id, :string
    attribute :email, :string
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
      expect(wildcard_handler.can_handle?("anything.happened")).to be true
    end
  end

  describe "#handle" do
    let(:event) do
      AuditTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        actor_email: "admin@example.com",
        user_id: "user-123",
        email: "newuser@example.com"
      )
    end

    it "logs audit event to structured logger" do
      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)

      expect(logger).to receive(:info) do |message|
        expect(message).to include("AUDIT")
        expect(message).to include("user.created")
        expect(message).to include("user-123")
        expect(message).to include("org-456")
      end

      handler.handle(event)
    end

    it "writes to audit table when enabled", :audit_table do
      # Enable audit table for this test
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      handler.handle(event)

      audit_event = AuditEvent.find_by(event_id: event.event_id)
      expect(audit_event).not_to be_nil
      expect(audit_event.event_type).to eq("user.created")
      expect(audit_event.aggregate_id).to eq("user-123")
      expect(audit_event.aggregate_type).to eq("User")
      expect(audit_event.organization_id).to eq("org-456")
      expect(audit_event.occurred_at).to be_within(1.second).of(event.occurred_at)
    end

    it "does not write to audit table when disabled" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(false)

      expect do
        handler.handle(event)
      end.not_to change(AuditEvent, :count)
    end

    it "categorizes authentication events" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      auth_event = AuditTestEvent.new(
        event_type: "user.logged_in",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "user-123",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(auth_event)

      audit_record = AuditEvent.find_by(event_id: auth_event.event_id)
      expect(audit_record.category).to eq("authentication")
    end

    it "categorizes data access events" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      access_event = AuditTestEvent.new(
        event_type: "user.viewed",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(access_event)

      audit_record = AuditEvent.find_by(event_id: access_event.event_id)
      expect(audit_record.category).to eq("data_access")
    end

    it "categorizes admin action events" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      admin_event = AuditTestEvent.new(
        event_type: "user.deleted",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(admin_event)

      audit_record = AuditEvent.find_by(event_id: admin_event.event_id)
      expect(audit_record.category).to eq("admin_action")
    end

    it "assesses risk level as HIGH for deletions" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      delete_event = AuditTestEvent.new(
        event_type: "user.deleted",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(delete_event)

      audit_record = AuditEvent.find_by(event_id: delete_event.event_id)
      expect(audit_record.risk_level).to eq("HIGH")
    end

    it "assesses risk level as MEDIUM for updates" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      update_event = AuditTestEvent.new(
        event_type: "user.updated",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(update_event)

      audit_record = AuditEvent.find_by(event_id: update_event.event_id)
      expect(audit_record.risk_level).to eq("MEDIUM")
    end

    it "assesses risk level as LOW for reads" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      read_event = AuditTestEvent.new(
        event_type: "user.viewed",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(read_event)

      audit_record = AuditEvent.find_by(event_id: read_event.event_id)
      expect(audit_record.risk_level).to eq("LOW")
    end

    it "stores event data as JSON" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      handler.handle(event)

      audit_record = AuditEvent.find_by(event_id: event.event_id)
      event_data = audit_record.event_data

      expect(event_data).to be_a(Hash)
      expect(event_data["user_id"]).to eq("user-123")
      expect(event_data["email"]).to eq("newuser@example.com")
      expect(event_data["actor_id"]).to eq("admin-789")
      expect(event_data["actor_email"]).to eq("admin@example.com")
    end

    it "handles errors gracefully" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)
      allow(AuditEvent).to receive(:create!).and_raise(StandardError, "Database error")

      logger = instance_double(Logger)
      allow(SmartDomain.configuration).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)

      expect(logger).to receive(:error).with(/Failed to write audit event/)

      # Should not raise
      expect { handler.handle(event) }.not_to raise_error
    end
  end

  describe "compliance features" do
    it "includes event_id for event tracking" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      event = AuditTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-123",
        aggregate_type: "User",
        organization_id: "org-456",
        actor_id: "admin-789",
        user_id: "user-123",
        email: "user@example.com"
      )

      handler.handle(event)

      audit_record = AuditEvent.find_by(event_id: event.event_id)
      expect(audit_record.event_id).to eq(event.event_id)
    end

    it "supports compliance queries by organization" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      event1 = AuditTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-1",
        aggregate_type: "User",
        organization_id: "org-1",
        actor_id: "admin-1",
        user_id: "user-1",
        email: "user1@example.com"
      )

      event2 = AuditTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-2",
        aggregate_type: "User",
        organization_id: "org-2",
        actor_id: "admin-2",
        user_id: "user-2",
        email: "user2@example.com"
      )

      handler.handle(event1)
      handler.handle(event2)

      org1_audits = AuditEvent.where(organization_id: "org-1")
      expect(org1_audits.count).to eq(1)
      expect(org1_audits.first.aggregate_id).to eq("user-1")
    end

    it "supports compliance queries by event type" do
      allow(SmartDomain.configuration).to receive(:audit_table_enabled?).and_return(true)

      create_event = AuditTestEvent.new(
        event_type: "user.created",
        aggregate_id: "user-1",
        aggregate_type: "User",
        organization_id: "org-1",
        actor_id: "admin-1",
        user_id: "user-1",
        email: "user@example.com"
      )

      delete_event = AuditTestEvent.new(
        event_type: "user.deleted",
        aggregate_id: "user-2",
        aggregate_type: "User",
        organization_id: "org-1",
        actor_id: "admin-1",
        user_id: "user-2",
        email: "user2@example.com"
      )

      handler.handle(create_event)
      handler.handle(delete_event)

      delete_audits = AuditEvent.where(event_type: "user.deleted")
      expect(delete_audits.count).to eq(1)
      expect(delete_audits.first.risk_level).to eq("HIGH")
    end
  end
end
