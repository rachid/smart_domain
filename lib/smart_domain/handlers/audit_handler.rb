# frozen_string_literal: true

module SmartDomain
  module Handlers
    # Generic audit handler for domain events.
    #
    # This handler provides standardized audit logging for any domain.
    # It logs all events with structured data and optionally writes to
    # an audit_events table for compliance.
    #
    # Features:
    # - Structured logging to Rails logger
    # - Optional database audit table writes
    # - Event categorization (authentication, data_access, admin_action, etc.)
    # - Risk level assessment (HIGH, MEDIUM, LOW)
    # - Field extraction from event mixins
    #
    # @example
    #   user_audit = SmartDomain::Handlers::AuditHandler.new('user')
    #   SmartDomain::Event.bus.subscribe('user.created', user_audit)
    #   SmartDomain::Event.bus.subscribe('user.updated', user_audit)
    #
    # Or use the registration helper for one-line setup:
    #   SmartDomain::Event::Registration.register_standard_handlers(
    #     domain: 'user',
    #     events: ['created', 'updated', 'deleted'],
    #     include_audit: true
    #   )
    class AuditHandler < Event::Handler
      attr_reader :domain, :logger

      # Initialize audit handler for a specific domain
      # @param domain [String] Domain name (e.g., 'user', 'order', 'product')
      def initialize(domain)
        super()
        @domain = domain
        @logger = SmartDomain.configuration.logger
      end

      # Check if this handler can handle an event type
      # @param event_type [String] Event type to check
      # @return [Boolean] True if event belongs to this domain
      def can_handle?(event_type)
        return true if @domain == '*'

        event_type.start_with?("#{@domain}.")
      end

      # Handle audit logging for an event
      # @param event [SmartDomain::Event::Base] Event to audit
      def handle(event)
        action = event.event_type.split('.').last

        # 1. Log to Rails logger (structured)
        log_audit_event(event, action)

        # 2. Write to audit_events table (if configured)
        write_to_audit_table(event) if SmartDomain.configuration.audit_table_enabled?
      rescue StandardError => e
        # Never fail on audit handler errors
        @logger.warn "[SmartDomain::AuditHandler] Audit logging failed: #{e.message}"
        @logger.warn e.backtrace.join("\n")
      end

      private

      # Log event to Rails logger with structured data
      # @param event [SmartDomain::Event::Base] Event to log
      # @param action [String] Event action (e.g., 'created', 'updated')
      def log_audit_event(event, action)
        log_data = build_log_data(event)
        message = "[AUDIT] #{event.aggregate_type} #{action}"
        @logger.info("#{message} - #{log_data.to_json}")
      end

      # Build structured log data from event
      # @param event [SmartDomain::Event::Base] Event to extract data from
      # @return [Hash] Structured log data
      def build_log_data(event)
        log_data = {
          audit: true,
          event_id: event.event_id,
          event_type: event.event_type,
          aggregate_type: event.aggregate_type,
          aggregate_id: event.aggregate_id,
          organization_id: event.organization_id,
          occurred_at: event.occurred_at.iso8601
        }

        # Add all event-specific fields (including mixin fields)
        event.attributes.each do |key, value|
          next if log_data.key?(key.to_sym) || value.nil?

          log_data[key.to_sym] = serialize_value(value)
        end

        log_data
      end

      # Serialize a value for logging
      # @param value [Object] Value to serialize
      # @return [Object] Serialized value
      def serialize_value(value)
        case value
        when Time, DateTime, Date
          value.iso8601
        when Hash, Array
          value
        else
          value
        end
      end

      # Write event to audit_events table for compliance
      # @param event [SmartDomain::Event::Base] Event to write
      def write_to_audit_table(event)
        return unless defined?(AuditEvent)

        AuditEvent.create!(
          event_id: event.event_id,
          event_type: event.event_type,
          aggregate_id: event.aggregate_id,
          aggregate_type: event.aggregate_type,
          organization_id: event.organization_id,
          category: map_event_category(event.event_type),
          risk_level: assess_risk_level(event.event_type),
          event_data: event.to_h,
          occurred_at: event.occurred_at
        )
      rescue StandardError => e
        @logger.warn "[SmartDomain::AuditHandler] Failed to write to audit table: #{e.message}"
      end

      # Map event type to audit category
      # @param event_type [String] Event type
      # @return [String] Audit category
      def map_event_category(event_type)
        case event_type
        when /^auth\.|logged_in|logged_out|login|logout|authenticated|password/
          'authentication'
        when /accessed|viewed|patient\./
          'data_access'
        when /created|updated|deleted|assigned|removed/
          'admin_action'
        else
          'system_event'
        end
      end

      # Assess risk level of event
      # @param event_type [String] Event type
      # @return [String] Risk level (HIGH, MEDIUM, LOW)
      def assess_risk_level(event_type)
        case event_type
        when /suspended|deleted|revoked|failed|rejected/
          'HIGH'
        when /updated|changed|assigned/
          'MEDIUM'
        else
          'LOW'
        end
      end

      # Extract actor_id from event (ActorMixin)
      # @param event [SmartDomain::Event::Base] Event
      # @return [String, nil] Actor ID
      def extract_actor_id(event)
        event.try(:actor_id) || event.attributes['actor_id']
      end

      # Extract ip_address from event (SecurityContextMixin)
      # @param event [SmartDomain::Event::Base] Event
      # @return [String, nil] IP address
      def extract_ip_address(event)
        event.try(:ip_address) || event.attributes['ip_address']
      end

      # Extract user_agent from event (SecurityContextMixin)
      # @param event [SmartDomain::Event::Base] Event
      # @return [String, nil] User agent
      def extract_user_agent(event)
        event.try(:user_agent) || event.attributes['user_agent']
      end

      # Extract old_values from event (ChangeTrackingMixin)
      # @param event [SmartDomain::Event::Base] Event
      # @return [Hash, nil] Old values
      def extract_old_values(event)
        event.try(:old_values) || event.attributes['old_values']
      end

      # Extract new_values from event (ChangeTrackingMixin)
      # @param event [SmartDomain::Event::Base] Event
      # @return [Hash, nil] New values
      def extract_new_values(event)
        event.try(:new_values) || event.attributes['new_values']
      end

      # Build compliance flags for audit record
      # @param event [SmartDomain::Event::Base] Event
      # @return [Hash] Compliance flags
      def build_compliance_flags(event)
        {
          event_id: event.event_id,
          aggregate_id: event.aggregate_id,
          aggregate_type: event.aggregate_type,
          domain: @domain,
          correlation_id: event.correlation_id,
          causation_id: event.causation_id
        }.compact
      end
    end
  end
end
